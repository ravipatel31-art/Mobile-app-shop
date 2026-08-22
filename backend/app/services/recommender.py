"""LLM-powered menu recommendations backed by a local Ollama model.

No Flask imports here: the route layer (app/routes/recommend.py) owns HTTP
concerns; this module only turns cart contents into suggestions. It never
raises on LLM trouble — callers always get usable suggestions, falling back
to the week's popular items when the model is slow, offline, or incoherent.

Latency note: llama3.1:8b runs at ~5 tok/s on the dev machine, so a call
takes ~12-25 s. num_predict stays low and results are cached to keep the
POS usable.
"""
import json
import re
import threading
import time
from datetime import datetime

from ..config import Config
from ..repositories import menu as menu_repo
from ..repositories import reports as reports_repo

# One process-wide lock so parallel POS clients don't stampede Ollama with
# identical prompts (the Flask dev server is threaded).
_lock = threading.Lock()
_chain = None
# Tests inject a fake via _chain_factory instead of importing langchain.
_chain_factory = None

_cache = {}  # (cart_ids, daypart, date, limit) -> (expires_at, suggestions, source)
_POPULAR_TTL = 300  # seconds; popularity barely moves mid-shift
_popular_cache = {"at": 0.0, "items": []}

_FALLBACK_REASONS = {
    "morning": "Popular pick this morning",
    "afternoon": "One of our best sellers this afternoon",
    "evening": "An evening favourite this week",
}


def _daypart(now=None):
    hour = (now or datetime.now()).hour
    if hour < 12:
        return "morning"
    if hour < 17:
        return "afternoon"
    return "evening"


def build_chain():
    """Create the LangChain pipeline once; None when langchain is absent."""
    global _chain
    if _chain is not None:
        return _chain
    try:
        from langchain_core.output_parsers import StrOutputParser
        from langchain_core.prompts import ChatPromptTemplate
        from langchain_ollama import ChatOllama
    except ImportError:
        return None

    llm = ChatOllama(
        base_url=Config.OLLAMA_BASE_URL,
        model=Config.OLLAMA_MODEL,
        temperature=0.3,
        num_predict=140,
        format="json",
        keep_alive="15m",
        client_kwargs={"timeout": Config.OLLAMA_TIMEOUT_S},
    )
    prompt = ChatPromptTemplate.from_messages(
        [
            (
                "system",
                "You are a cafe upsell engine. Output ONLY a JSON array of "
                "objects with exactly the keys 'item_id' and 'reason'. "
                "No prose, no markdown.",
            ),
            (
                "human",
                "MENU (candidate items): {menu_json}\n"
                "ALREADY IN CART (never suggest these): {cart_json}\n"
                "BEST SELLERS LAST 7 DAYS: {popular_json}\n"
                "Time of day: {daypart}. Return a JSON array of up to "
                "{limit} items that pair well with the cart for this time "
                "of day. Each reason must be at most 12 words.",
            ),
        ]
    )
    _chain = prompt | llm | StrOutputParser()
    return _chain


def parse_suggestions(text, allowed_ids, limit):
    """Extract valid {item_id, reason} pairs from raw LLM output.

    Tolerates code fences, Ollama JSON-mode's wrapped object shape
    ({"items": [...]}) and stray prose. Pure function — unit tested.
    """
    if not text:
        return []
    cleaned = text.strip()
    fenced = re.search(r"```(?:json)?\s*([\s\S]*?)```", cleaned)
    if fenced:
        cleaned = fenced.group(1).strip()

    data = None
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        match = re.search(r"\[[\s\S]*\]", cleaned)
        if match:
            try:
                data = json.loads(match.group(0))
            except json.JSONDecodeError:
                return []

    if isinstance(data, dict):
        # JSON mode wraps arrays: {"items": [...]} or any single list value.
        for value in data.values():
            if isinstance(value, list):
                data = value
                break
        else:
            # Small models sometimes emit one bare suggestion object.
            if "item_id" in data or "id" in data:
                data = [data]
    if not isinstance(data, list):
        return []

    seen, out = set(), []
    for entry in data:
        if not isinstance(entry, dict):
            continue
        item_id = entry.get("item_id", entry.get("id"))
        if not isinstance(item_id, str) or item_id not in allowed_ids or item_id in seen:
            continue
        seen.add(item_id)
        out.append({"item_id": item_id, "reason": str(entry.get("reason", "")).strip()[:160]})
        if len(out) >= limit:
            break
    return out


def _get_popular():
    """Week's top sellers, cached briefly (scan-free GSI queries)."""
    now = time.time()
    if _popular_cache["items"] and now - _popular_cache["at"] < _POPULAR_TTL:
        return _popular_cache["items"]
    try:
        items = reports_repo.top_items(days=Config.POPULAR_DAYS, top_n=10)
    except Exception:
        items = []
    _popular_cache["at"] = now
    _popular_cache["items"] = items
    return items


def _default_options(item):
    """First choice of each required single-choice group.

    Returns (defaults, safe_to_autopick). safe is False when some required
    group allows multiple picks — then there is no obvious default and the
    app should open the detail screen instead of adding blind.
    """
    defaults = []
    safe = True
    for group in item.get("options") or []:
        choices = group.get("choices") or []
        if group.get("required"):
            if not choices:
                safe = False
            elif not group.get("multi"):
                defaults.append({"group": group["group"], "label": choices[0].get("label", "")})
            else:
                safe = False
    return defaults, safe


def _present(suggestions, by_id):
    """Attach full item dicts + default options for one-tap add."""
    out = []
    for s in suggestions:
        item = by_id[s["item_id"]]
        defaults, _safe = _default_options(item)
        unit = int(item.get("base_price", 0))
        chosen = {(d["group"], d["label"]) for d in defaults}
        for group in item.get("options") or []:
            if group.get("multi"):
                continue  # multi groups are extras; defaults never include them
            for choice in group.get("choices") or []:
                if (group["group"], choice.get("label")) in chosen:
                    unit += int(choice.get("price_delta", 0))
        out.append({
            "item_id": s["item_id"],
            "reason": s["reason"],
            "unit_price": unit,
            "default_options": defaults,
            "safe_to_autopick": _safe,
            "item": item,
        })
    return out


def recommend(cart_lines, limit=None):
    """Return (suggestions, source) for a cart; never raises.

    source is "llm" when the model produced usable suggestions, else
    "popular". Suggestions embed their menu item dicts ready for jsonify.
    """
    try:
        limit = int(limit or Config.RECOMMEND_LIMIT)
    except (TypeError, ValueError):
        limit = Config.RECOMMEND_LIMIT
    limit = max(1, min(limit, 5))

    items = menu_repo.list_items()
    by_id = {i["id"]: i for i in items if i.get("available", True)}
    cart_ids = {str(c.get("item_id")) for c in cart_lines or [] if c.get("item_id")}
    daypart = _daypart()
    today = datetime.now().strftime("%Y-%m-%d")

    key = (tuple(sorted(cart_ids)), daypart, today, limit)
    now = time.time()
    hit = _cache.get(key)
    if hit and hit[0] > now:
        return hit[1], hit[2]

    popular = [p for p in _get_popular() if p["item_id"] not in cart_ids]
    suggestions, source = [], "popular"

    chain = _chain_factory() if _chain_factory is not None else build_chain()
    if chain is not None:
        menu_brief = [
            {
                "item_id": i["id"],
                "name": i.get("name"),
                "category": i.get("category"),
                "price": i.get("base_price"),
                "description": (i.get("description") or "")[:80],
            }
            for i in by_id.values() if i["id"] not in cart_ids
        ]
        inputs = {
            "menu_json": json.dumps(menu_brief),
            "cart_json": json.dumps(
                [{"item_id": c.get("item_id"), "qty": c.get("qty", 1)} for c in cart_lines or []]
            ),
            "popular_json": json.dumps(popular[:10]),
            "daypart": daypart,
            "limit": limit,
        }
        try:
            text = chain.invoke(inputs)
            parsed = parse_suggestions(text, set(by_id) - cart_ids, limit)
            if parsed:
                suggestions, source = parsed, "llm"
        except Exception:
            suggestions, source = [], "popular"

    if not suggestions:
        suggestions = [
            {"item_id": p["item_id"], "reason": _FALLBACK_REASONS[daypart]}
            for p in popular[:limit]
        ]
        source = "popular"

    result = _present(suggestions, by_id)
    with _lock:
        _cache[key] = (now + Config.RECOMMEND_CACHE_TTL, result, source)
        # Opportunistic cleanup so long-running processes don't grow forever.
        for k in [k for k, v in _cache.items() if v[0] <= now]:
            _cache.pop(k, None)
    return result, source

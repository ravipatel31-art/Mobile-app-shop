"""Agentic Q&A over POS data using a local Ollama model.

Manual tool loop instead of a framework agent: the model sees a JSON
catalogue of read-only tools and must reply with exactly one of

    {"tool": "<name>", "args": {...}}      run a read-only tool, feed the
                                           result back for a final answer
    {"action": "<name>", "args": {...}}    propose a WRITE action — never
                                           executed here, returned to the
                                           client as pending_action for
                                           human confirmation
    {"answer": "..." }                     direct answer (greetings etc.)

so a full exchange is at most two LLM calls (~20-25 s on this hardware).

Financial report tools are only offered to owners, mirroring the route-level
gating on /admin/reports. The model never talks to DynamoDB itself — tools
run repo functions server-side and only trimmed results go back into the
prompt.

Tests inject a fake LLM via _llm_factory; nothing here raises to the caller.
"""
import json
import re
import threading
from datetime import datetime

from ..config import Config
from ..repositories import menu as menu_repo
from ..repositories import orders as orders_repo
from ..repositories import reports as reports_repo
from ..repositories import tables as tables_repo

_lock = threading.Lock()
_llm = None
# Tests replace this to inject a fake; signature: () -> llm | None.
_llm_factory = None

# Actions the agent may PROPOSE (executed only via /ask/execute).
ALLOWED_ACTIONS = ("free_table", "advance_order")

_ACTION_LABELS = {
    "free_table": lambda args: f"Free table {args.get('table_number', '?')}",
    "advance_order": lambda args: (
        f"Move order {args.get('order_id', '?')} to its next status"),
}

def _money(minor):
    """Minor units (paise) -> '₹18.00'.

    Tool results expose ONLY formatted rupees: small models reliably copy a
    ready-made string but will read a raw 1800 as ₹1800 (seen in practice).
    """
    try:
        return f"₹{int(minor) / 100:,.2f}"
    except (TypeError, ValueError):
        return str(minor)


_SELECT_PROMPT = """You are the assistant built into a cafe POS app. Staff ask you about live sales data. Today is {today} ({daypart}).

TOOLS you may call (reply {{"tool": name, "args": {{...}}}}):
{tools}

When the user asks to CHANGE something (free a table, move an order along), reply {{"action": "<name>", "args": {{...}}}} — allowed actions: {actions}.

For greetings or anything no tool helps with, reply {{"answer": "..."}}.

Reply with EXACTLY ONE of those JSON objects and nothing else.

User question: {question}"""

_ANSWER_PROMPT = """You are the assistant of a cafe POS app. Answer the user's question using ONLY this tool result.

Question: {question}

Tool result: {result}

Answer in 1-4 short sentences of plain English with the concrete numbers/ids. Money values arrive as formatted rupee strings (e.g. ₹18.00) — copy them EXACTLY; never multiply, divide or reconvert them. Never copy JSON into the answer — turn it into words. If the result is empty, say there is nothing yet (e.g. "No orders so far today."). Reply as JSON: {{"answer": "Top sellers were Cappuccino (x4) and Muffin (x3)."}}"""


def _get_llm():
    global _llm
    if _llm is not None:
        return _llm
    try:
        from langchain_ollama import ChatOllama
    except ImportError:
        return None
    _llm = ChatOllama(
        base_url=Config.OLLAMA_BASE_URL,
        model=Config.OLLAMA_MODEL,
        temperature=0.0,
        num_predict=200,
        format="json",
        keep_alive="15m",
        client_kwargs={"timeout": Config.ASK_TIMEOUT_S},
    )
    return _llm


def _tool_catalog(role):
    tools = [
        {"name": "list_orders",
         "description": "Recent orders (id, status, table, total, items).",
         "args": {"status": "optional: received/preparing/ready/collected",
                  "date": "optional YYYY-MM-DD"}},
        {"name": "get_order",
         "description": "One order's full details.",
         "args": {"order_id": "required"}},
        {"name": "tables_status",
         "description": "Every table with occupied/empty and who serves it.",
         "args": {}},
        {"name": "menu_items",
         "description": "Menu items with prices and availability.",
         "args": {}},
        {"name": "popular_items",
         "description": "Best-selling items by quantity over recent days.",
         "args": {"days": "optional int"}},
    ]
    if role == "owner":
        tools.append({
            "name": "daily_sales",
            "description": "One day's revenue summary (owner only).",
            "args": {"date": "optional YYYY-MM-DD, default today"},
        })
    return tools


def _run_tool(name, args, role):
    """Run one read-only tool; returns JSON-serializable data."""
    args = args if isinstance(args, dict) else {}
    try:
        if name == "list_orders":
            orders = orders_repo.list_orders(
                status=args.get("status") or None,
                order_date=args.get("date") or None)
            return [
                {
                    "id": o.get("id"),
                    "status": o.get("status"),
                    "table": o.get("table_number"),
                    "total": _money(o.get("total")),
                    "items": [f"{l.get('name')} x{l.get('qty')}"
                              for l in o.get("items", [])],
                }
                for o in orders[:20]
            ]
        if name == "get_order":
            raw = _first_arg(args, "order_id", "order", "id")
            order = orders_repo.get(str(raw or ""))
            if not order:
                return {"error": "Order not found"}
            order = dict(order)
            order["total"] = _money(order.get("total"))
            order["items"] = [
                {**line, "line_total": _money(line.get("line_total"))}
                for line in order.get("items", [])
            ]
            return order
        if name == "tables_status":
            return [
                {"number": t.get("number"), "status": t.get("status"),
                 "served_by": t.get("taken_by")}
                for t in tables_repo.list_all()
            ]
        if name == "menu_items":
            return [
                {"id": m["id"], "name": m.get("name"),
                 "category": m.get("category"),
                 "price": _money(m.get("base_price")),
                 "available": m.get("available")}
                for m in menu_repo.list_items()
            ]
        if name == "popular_items":
            try:
                days = min(int(args.get("days") or Config.POPULAR_DAYS), 30)
            except (TypeError, ValueError):
                days = Config.POPULAR_DAYS
            return reports_repo.top_items(days=max(days, 1), top_n=5)
        if name == "daily_sales" and role == "owner":
            summary = reports_repo.daily_summary(args.get("date")
                                                 or datetime.now().strftime("%Y-%m-%d"))
            out = {k: summary[k] for k in
                   ("date", "order_count", "gross_sales", "by_category",
                    "top_items")}
            out["gross_sales"] = _money(out["gross_sales"])
            out["by_category"] = {cat: _money(rev)
                                  for cat, rev in out["by_category"].items()}
            out["top_items"] = [{**t, "revenue": _money(t.get("revenue"))}
                                for t in out["top_items"]]
            return out
        return {"error": f"Unknown tool '{name}'"}
    except Exception as exc:  # surface tool failure to the model, not the caller
        return {"error": str(exc)}


def _parse_json_object(text):
    """Parse an LLM reply into a dict; tolerates fences and stray prose."""
    if isinstance(text, dict):
        return text
    cleaned = (text or "").strip()
    fenced = re.search(r"```(?:json)?\s*([\s\S]*?)```", cleaned)
    if fenced:
        cleaned = fenced.group(1).strip()
    try:
        data = json.loads(cleaned)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        match = re.search(r"\{[\s\S]*\}", cleaned)
        if match:
            try:
                data = json.loads(match.group(0))
                return data if isinstance(data, dict) else {}
            except json.JSONDecodeError:
                return {}
    return {}


def _first_arg(args, *keys):
    """First non-empty value among aliased arg names (small models rename
    keys freely: table_number / table_id / table ...)."""
    for k in keys:
        v = args.get(k)
        if v is not None and str(v).strip():
            return v
    return None


def _sanitize_action_args(action, args):
    args = args if isinstance(args, dict) else {}
    if action == "free_table":
        raw = _first_arg(args, "table_number", "table_id", "table", "number")
        number = re.sub(r"\D", "", str(raw or ""))
        return {"table_number": number} if number else None
    if action == "advance_order":
        raw = _first_arg(args, "order_id", "order", "id")
        order_id = re.sub(r"[^A-Za-z0-9]", "", str(raw or ""))
        return {"order_id": order_id.upper()} if order_id else None
    return None


def _render_result(data):
    """Deterministic plain rendering when the model can't produce prose."""
    if isinstance(data, list) and data and isinstance(data[0], dict):
        parts = []
        for item in data[:8]:
            fields = ", ".join(f"{k}={v}" for k, v in item.items()
                               if v not in (None, ""))
            if fields:
                parts.append(fields)
        return "; ".join(parts) or "No matching records found."
    return json.dumps(data)[:400]


def _answer_from_text(text):
    """Pull human prose out of an LLM reply shaped as an object OR a list.

    Small models sometimes skip the instructed {"answer": "..."} wrapper and
    return e.g. ["cappuccino", "muffin"] directly.
    """
    cleaned = (text or "").strip()
    fenced = re.search(r"```(?:json)?\s*([\s\S]*?)```", cleaned)
    if fenced:
        cleaned = fenced.group(1).strip()
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        match = re.search(r"\{[\s\S]*\}|\[[\s\S]*\]", cleaned)
        if not match:
            return cleaned[:400]
        try:
            data = json.loads(match.group(0))
        except json.JSONDecodeError:
            return cleaned[:400]
    if isinstance(data, dict):
        answer = data.get("answer")
        if isinstance(answer, str) and answer.strip():
            return answer.strip()
        for value in data.values():  # {"result": "..."} etc.
            if isinstance(value, str) and value.strip():
                return value.strip()
        return ""
    if isinstance(data, list):
        flat = []
        for item in data:
            if isinstance(item, dict):
                name = item.get("name") or item.get("item_id") or ""
                qty = item.get("qty")
                flat.append(f"{name} (x{qty})" if qty else str(name))
            else:
                flat.append(str(item))
        return ", ".join(x for x in flat if x and x != "None")
    return str(data)[:400]


def ask(question, role):
    """Full Q&A turn; returns {answer, source, pending_action}, never raises."""
    result = {"answer": "", "source": "agent", "pending_action": None}
    llm = _llm_factory() if _llm_factory is not None else _get_llm()
    if llm is None:
        result["answer"] = ("The AI assistant backend is unavailable "
                            "(langchain-ollama is not installed).")
        result["source"] = "unavailable"
        return result

    now = datetime.now()
    select_inputs = {
        "tools": json.dumps(_tool_catalog(role)),
        "actions": ", ".join(ALLOWED_ACTIONS),
        "question": question,
        "today": now.strftime("%Y-%m-%d"),
        "daypart": recommender_daypart(now),
    }

    def fail(message):
        result["answer"] = message
        result["source"] = "error"
        return result

    try:
        with _lock:
            decision = _parse_json_object(llm.invoke(
                _SELECT_PROMPT.format(**select_inputs)).content)

            action = decision.get("action")
            if action in ALLOWED_ACTIONS:
                args = _sanitize_action_args(action, decision.get("args"))
                if args is None:
                    return fail("I couldn't work out which table/order you "
                                "meant. Try naming it explicitly.")
                result["pending_action"] = {
                    "action": action,
                    "args": args,
                    "label": _ACTION_LABELS[action](args),
                    "args_json": json.dumps(decision.get("args") or {}),
                }
                result["answer"] = "Confirm this action to proceed."
                return result
            if action is not None:
                return fail("That change isn't something I'm allowed to do. "
                            "I can propose freeing a table or advancing an "
                            "order's status.")

            tool = decision.get("tool")
            if not tool:
                answer = str(decision.get("answer", "")).strip()
                if not answer:
                    return fail("I couldn't process that question. Try asking "
                                "about orders, tables, the menu, or sales.")
                result["answer"] = answer
                return result

            # One round-trip max: run the tool, then have the model answer.
            allowed = {t["name"] for t in _tool_catalog(role)}
            if tool not in allowed:
                return fail(f"I don't have access to a '{tool}' tool.")
            tool_result = _run_tool(tool, decision.get("args"), role)
            answer_msg = llm.invoke(_ANSWER_PROMPT.format(
                question=question,
                result=json.dumps(tool_result)[:4000],
            )).content
            answer = _answer_from_text(answer_msg)
            if not answer or re.search(r'[{}\[\]"]', answer):
                # Model echoed raw JSON instead of prose — render it ourselves.
                if tool_result in ([], {}):
                    result["answer"] = "No matching records found."
                else:
                    result["answer"] = _render_result(tool_result)
                return result
            result["answer"] = answer
            return result
    except Exception as exc:
        return fail(f"The AI assistant couldn't reach the model ({exc}). "
                    "Is Ollama running?")


def recommender_daypart(now=None):
    """Shared daypart string (morning/afternoon/evening)."""
    hour = (now or datetime.now()).hour
    if hour < 12:
        return "morning"
    if hour < 17:
        return "afternoon"
    return "evening"

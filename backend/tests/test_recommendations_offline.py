"""Offline tests for POST /recommend using an in-memory boto3 stub and a
faked LangChain chain (no network, no Ollama). Covers auth, request
validation, LLM output parsing/sanitizing, and the popular-items fallback.

Run:  python tests/test_recommendations_offline.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "_stubs"))
sys.path.insert(0, BACKEND)

os.environ["AWS_REGION"] = "us-east-1"
os.environ.pop("AWS_ENDPOINT_URL", None)
os.environ["SEED_ADMIN_USER"] = "owner"
os.environ["SEED_ADMIN_PASSWORD"] = "cafe123"

from app import create_app  # noqa: E402
from app.infra import ensure_infra, seed_all  # noqa: E402
from app.services import recommender  # noqa: E402


class FakeChain:
    """Stand-in for the prompt|llm|parser runnable; returns canned text."""

    def __init__(self, text):
        self.text = text
        self.inputs = None

    def invoke(self, inputs):
        self.inputs = inputs
        return self.text


def main():
    ensure_infra()
    seed_all()

    app = create_app()
    c = app.test_client()
    fails = []

    def ok(name, cond):
        if not cond:
            fails.append(name)
            print("FAIL:", name)

    def bearer(token):
        return {"Authorization": "Bearer " + token}

    def set_chain(text=None, exc=None):
        if exc is not None:
            class Boom:
                def invoke(self, _):
                    raise exc()
            fake = Boom()
        else:
            fake = FakeChain(text)
        recommender._chain_factory = lambda: fake
        recommender._cache.clear()

    staff = c.post("/auth/login",
                   json={"username": "priya", "password": "staff123"}).get_json()
    sauth = bearer(staff["token"])

    # ---- auth + validation ----
    ok("no token 401", c.post("/recommend", json={"cart": [{"item_id": "latte"}]}).status_code == 401)
    ok("empty cart 400",
       c.post("/recommend", headers=sauth, json={"cart": []}).status_code == 400)

    # ---- happy path: valid suggestions survive, junk is filtered ----
    set_chain(json.dumps([
        {"item_id": "croissant", "reason": "Buttery pair for a latte"},
        {"item_id": "bogus-id", "reason": "not on the menu"},
        {"item_id": "latte", "reason": "already in the cart"},
        {"item_id": "chai", "reason": "Spiced and warming"},
        {"item_id": "croissant", "reason": "duplicate entry"},
        {"item_id": "muffin", "reason": "Sweet finish"},
    ]))
    res = c.post("/recommend", headers=sauth,
                 json={"cart": [{"item_id": "latte", "qty": 1}], "limit": 3})
    body = res.get_json()
    ok("llm 200", res.status_code == 200)
    ok("source is llm", body["source"] == "llm")
    ids = [s["item_id"] for s in body["suggestions"]]
    ok("unknown/cart/dupes filtered", ids == ["croissant", "chai", "muffin"])
    ok("limit respected", len(body["suggestions"]) <= 3)
    ok("elapsed_ms reported", isinstance(body["elapsed_ms"], int))
    s0 = body["suggestions"][0]
    ok("full item embedded",
       s0["item"]["id"] == "croissant" and "image_url" in s0["item"]
       and s0["item"]["available"] is True)
    ok("unit_price present", isinstance(s0["unit_price"], int))
    ok("croissant has no required options", s0["default_options"] == [])

    chai_s = next(s for s in body["suggestions"] if s["item_id"] == "chai")
    ok("required group defaulted",
       any(d["group"] == "Size" and d["label"] for d in chai_s["default_options"]))
    ok("autopick safe when only single-choice required groups",
       chai_s["safe_to_autopick"] is True)
    ok("unit price includes default delta", chai_s["unit_price"] >= chai_s["item"]["base_price"])

    # prompt saw the cart and a menu without the cart item
    inputs = recommender._chain_factory().inputs
    ok("prompt received cart", "latte" in inputs["cart_json"])
    ok("prompt hides cart item from menu", '"latte"' not in inputs["menu_json"])

    # ---- Ollama JSON-mode wrapped shape ----
    set_chain(json.dumps({"items": [
        {"item_id": "muffin", "reason": "Wrapped shape still parses"},
    ]}))
    body = c.post("/recommend", headers=sauth,
                  json={"cart": [{"item_id": "latte", "qty": 1}]}).get_json()
    ok("wrapped dict unwrapped",
       body["source"] == "llm" and [s["item_id"] for s in body["suggestions"]] == ["muffin"])

    # ---- fenced output ----
    set_chain('```json\n[{"item_id": "muffin", "reason": "fenced but fine"}]\n```')
    body = c.post("/recommend", headers=sauth,
                  json={"cart": [{"item_id": "latte", "qty": 1}]}).get_json()
    ok("code fences stripped",
       body["source"] == "llm" and len(body["suggestions"]) == 1)

    # ---- garbage -> popular fallback ----
    set_chain("I am sorry, I cannot help with that.")
    body = c.post("/recommend", headers=sauth,
                  json={"cart": [{"item_id": "latte", "qty": 1}]}).get_json()
    ok("garbage falls back to popular", res.status_code == 200 and body["source"] == "popular")
    ok("popular excludes cart item",
       all(s["item_id"] != "latte" for s in body["suggestions"]))
    ok("fallback reasons filled", all(s["reason"] for s in body["suggestions"]))

    # ---- raising chain -> popular fallback, still 200 ----
    set_chain(exc=RuntimeError)
    res = c.post("/recommend", headers=sauth,
                 json={"cart": [{"item_id": "chai", "qty": 2}]})
    body = res.get_json()
    ok("chain crash tolerated 200", res.status_code == 200 and body["source"] == "popular")

    # ---- pure parser checks ----
    allowed = {"latte", "chai"}
    ok("parse: plain array",
       [s["item_id"] for s in recommender.parse_suggestions(
           '[{"item_id": "latte", "reason": "r"}]', allowed, 3)] == ["latte"])
    ok("parse: non-dict entries skipped",
       recommender.parse_suggestions('[{"item_id":"latte","reason":"r"}, 42]', allowed, 3)
       and len(recommender.parse_suggestions(
           '[{"item_id":"latte","reason":"r"}, 42]', allowed, 3)) == 1)
    ok("parse: limit enforced",
       len(recommender.parse_suggestions(json.dumps([
           {"item_id": "latte", "reason": "a"},
           {"item_id": "chai", "reason": "b"}]), allowed, 1)) == 1)
    ok("parse: empty input", recommender.parse_suggestions("", allowed, 3) == [])
    ok("parse: bare single object",
       [s["item_id"] for s in recommender.parse_suggestions(
           '{"item_id": "chai", "reason": "one suggestion only"}', allowed, 3)] == ["chai"])

    recommender._chain_factory = None

    if fails:
        print(f"\n{len(fails)} CHECK(S) FAILED")
        sys.exit(1)
    print("\nALL RECOMMENDER CHECKS PASSED")


if __name__ == "__main__":
    main()

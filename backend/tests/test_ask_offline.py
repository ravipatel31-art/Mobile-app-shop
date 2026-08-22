"""Offline tests for the agentic assistant: POST /ask (tool loop, action
proposals, role-filtered tools) and POST /ask/execute (auth + table-lock +
payment rules). Uses the boto3 stub and a scripted fake LLM.

Run:  python tests/test_ask_offline.py
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
from app.services import assistant  # noqa: E402


class FakeLLM:
    """Scripted replies, one per invoke() call; records prompts."""

    def __init__(self, replies):
        self.replies = list(replies)
        self.prompts = []

    def invoke(self, prompt):
        self.prompts.append(str(prompt))
        class _Msg:
            content = self.replies[min(len(self.prompts) - 1,
                                       len(self.replies) - 1)]
        return _Msg()


class BoomLLM:
    def invoke(self, prompt):
        raise RuntimeError("model offline")


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

    def set_llm(*replies):
        fake = FakeLLM(list(replies))
        assistant._llm_factory = lambda: fake
        return fake

    owner = c.post("/auth/login",
                   json={"username": "owner", "password": "cafe123"}).get_json()
    oauth = bearer(owner["token"])
    staff = c.post("/auth/login",
                   json={"username": "priya", "password": "staff123"}).get_json()
    sauth = bearer(staff["token"])

    # ---- auth + validation ----
    ok("ask no token 401",
       c.post("/ask", json={"question": "hi"}).status_code == 401)
    ok("ask empty question 400",
       c.post("/ask", headers=sauth, json={"question": "  "}).status_code == 400)
    ok("execute no token 401",
       c.post("/ask/execute", json={"action": "free_table",
                                    "args": {"table_number": "5"}}).status_code == 401)

    # ---- direct answer path ----
    fake = set_llm('{"answer": "Hello! Ask me about orders or tables."}')
    body = c.post("/ask", headers=sauth,
                  json={"question": "hello"}).get_json()
    ok("direct answer", body["source"] == "agent"
       and "Hello" in body["answer"] and body["pending_action"] is None)
    ok("staff prompt hides daily_sales", "daily_sales" not in fake.prompts[0])
    ok("staff prompt lists tables_status", "tables_status" in fake.prompts[0])

    # owner sees the financial tool
    fake = set_llm('{"answer": "ok"}')
    c.post("/ask", headers=oauth, json={"question": "hello"}).get_json()
    ok("owner prompt includes daily_sales", "daily_sales" in fake.prompts[0])

    # ---- tool loop: select then answer ----
    fake = set_llm(
        '{"tool": "tables_status", "args": {}}',
        '{"answer": "Tables 1-10 are empty."}',
    )
    body = c.post("/ask", headers=sauth,
                  json={"question": "which tables are busy?"}).get_json()
    ok("tool loop answered", body["source"] == "agent"
       and "empty" in body["answer"])
    ok("second prompt carries tool result",
       "tables_status" in fake.prompts[1]
       or "Table" in fake.prompts[1] or '"number"' in fake.prompts[1])

    # unknown tool is refused without crashing
    set_llm('{"tool": "delete_database", "args": {}}')
    body = c.post("/ask", headers=sauth,
                  json={"question": "nuke it"}).get_json()
    ok("unknown tool refused", body["source"] == "error"
       and "don't have access" in body["answer"])

    # ---- write intent becomes a proposal, never executed ----
    fake = set_llm('{"action": "free_table", "args": {"table_number": "5"}}')
    before = next(t for t in c.get("/tables", headers=sauth).get_json()
                  if t["number"] == "5")
    body = c.post("/ask", headers=sauth,
                  json={"question": "free table 5 please"}).get_json()
    pa = body.get("pending_action")
    ok("free_table proposed", pa is not None
       and pa["action"] == "free_table" and pa["args"]["table_number"] == "5")
    ok("human-readable label", pa["label"] == "Free table 5")
    after = next(t for t in c.get("/tables", headers=sauth).get_json()
                 if t["number"] == "5")
    ok("nothing executed on proposal", before["status"] == after["status"])

    # disallowed action names are refused outright
    set_llm('{"action": "cancel_all_orders", "args": {}}')
    body = c.post("/ask", headers=sauth,
                  json={"question": "cancel everything"}).get_json()
    ok("disallowed action refused", body["pending_action"] is None
       and "allowed to do" in body["answer"])

    # unparseable args -> clean refusal
    set_llm('{"action": "free_table", "args": {}}')
    body = c.post("/ask", headers=sauth,
                  json={"question": "free the table"}).get_json()
    ok("missing table number refused", body["pending_action"] is None)

    # ---- model offline / crash -> graceful error ----
    def boom():
        return BoomLLM()
    assistant._llm_factory = boom
    body = c.post("/ask", headers=sauth,
                  json={"question": "hello"}).get_json()
    ok("crash handled gracefully", body["source"] == "error"
       and "couldn't reach the model" in body["answer"])
    assistant._llm_factory = None

    # ================= /ask/execute =================

    # free_table: staff cannot free a table served by someone else.
    # Order o2 below is created by priya on table 6; sam would be blocked.
    sam_login = c.post("/auth/register",
                       json={"username": "execsam", "password": "pw123",
                             "name": "Exec Sam"})
    c.post("/admin/staff/execsam/approve", headers=oauth)
    sam = c.post("/auth/login",
                 json={"username": "execsam", "password": "pw123"}).get_json()
    samauth = bearer(sam["token"])

    order = c.post("/orders", headers=sauth, json={
        "table_number": 8,
        "items": [{"item_id": "latte", "qty": 1,
                   "selected_options": [{"group": "Size", "label": "Small"}]}],
    }).get_json()

    ok("execute free: wrong staff locked out 403",
       c.post("/ask/execute", headers=samauth,
              json={"action": "free_table",
                    "args": {"table_number": "8"}}).status_code == 403)
    ok("execute free: serving staff allowed",
       c.post("/ask/execute", headers=sauth,
              json={"action": "free_table",
                    "args": {"table_number": "8"}}).status_code == 200)
    t8 = next(t for t in c.get("/tables", headers=sauth).get_json()
              if t["number"] == "8")
    ok("execute free actually freed", t8["status"] == "empty")

    ok("execute free: missing arg 400",
       c.post("/ask/execute", headers=oauth,
              json={"action": "free_table", "args": {}}).status_code == 400)

    # advance_order: received -> preparing -> ready -> collected(needs payment)
    ok("advance to preparing 200",
       c.post("/ask/execute", headers=sauth,
              json={"action": "advance_order",
                    "args": {"order_id": order["id"]}}).status_code == 200)
    ok("advance to ready 200",
       c.post("/ask/execute", headers=sauth,
              json={"action": "advance_order",
                    "args": {"order_id": order["id"]}}).status_code == 200)
    res = c.post("/ask/execute", headers=sauth,
                 json={"action": "advance_order",
                       "args": {"order_id": order["id"]}})
    ok("collect without payment 400 with hint",
       res.status_code == 400 and "Payment is required" in res.get_json()["error"])
    ok("collect with paid flag 200",
       c.post("/ask/execute", headers=sauth,
              json={"action": "advance_order", "paid": True,
                    "args": {"order_id": order["id"]}}).status_code == 200)
    ok("advance past collected 409",
       c.post("/ask/execute", headers=sauth,
              json={"action": "advance_order",
                    "args": {"order_id": order["id"]}}).status_code == 409)
    ok("unknown action 400",
       c.post("/ask/execute", headers=oauth,
              json={"action": "delete_orders",
                    "args": {}}).status_code == 400)
    ok("bad order id 404",
       c.post("/ask/execute", headers=oauth,
              json={"action": "advance_order",
                    "args": {"order_id": "ZZZZZZ"}}).status_code == 404)

    if fails:
        print(f"\n{len(fails)} CHECK(S) FAILED")
        sys.exit(1)
    print("\nALL ASSISTANT CHECKS PASSED")


if __name__ == "__main__":
    main()

"""Offline end-to-end smoke test using an in-memory boto3 stub (no network,
no Floci). Covers the POS flow: owner login, staff register/approve, staff
login, tables, order -> table occupied -> collected -> table freed, reports,
menu add/delete, table add/remove.

Run:  python tests/smoke_offline.py
"""
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

    ok("health", c.get("/health").get_json()["status"] == "ok")

    # ---- owner login ----
    login = c.post("/auth/login",
                   json={"username": "owner", "password": "cafe123"})
    ok("owner login 200", login.status_code == 200)
    owner = login.get_json()
    ok("owner role", owner["role"] == "owner")
    oauth = bearer(owner["token"])

    # ---- staff self-register -> pending, cannot log in yet ----
    reg = c.post("/auth/register",
                 json={"username": "newbie", "password": "pw123", "name": "Newbie"})
    ok("register 201", reg.status_code == 201)
    pending_login = c.post("/auth/login",
                           json={"username": "newbie", "password": "pw123"})
    ok("pending login blocked 403", pending_login.status_code == 403)

    # ---- owner sees pending + approves ----
    staff_list = c.get("/admin/staff", headers=oauth).get_json()
    ok("staff list includes newbie",
       any(s["username"] == "newbie" and s["status"] == "pending" for s in staff_list))
    ok("no password hash leaked",
       all("password_hash" not in s for s in staff_list))
    c.post("/admin/staff/newbie/approve", headers=oauth)

    # now newbie can log in
    slog = c.post("/auth/login", json={"username": "newbie", "password": "pw123"})
    ok("approved staff login 200", slog.status_code == 200)
    staff = slog.get_json()
    ok("staff role", staff["role"] == "staff")
    sauth = bearer(staff["token"])

    # staff cannot reach owner-only endpoints
    ok("staff blocked from reports",
       c.get("/admin/reports/daily", headers=sauth).status_code == 403)
    ok("orders need auth", c.get("/orders").status_code == 401)

    # ---- tables: default 10, all empty ----
    tables = c.get("/tables", headers=sauth).get_json()
    ok("10 default tables", len(tables) == 10)
    ok("all empty", all(t["status"] == "empty" for t in tables))

    # ---- staff takes an order for table 5 ----
    order = c.post("/orders", headers=sauth, json={
        "table_number": 5,
        "items": [{"item_id": "latte", "qty": 2, "selected_options": [
            {"group": "Size", "label": "Large"}, {"group": "Milk", "label": "Oat"}]}],
    })
    ok("order created 201", order.status_code == 201)
    oid = order.get_json()["id"]
    ok("order total 900", order.get_json()["total"] == 900)
    ok("order taken_by staff", order.get_json()["taken_by"] == "newbie")

    # table 5 now occupied and linked to the order
    t5 = c.get("/tables", headers=sauth).get_json()
    t5 = next(t for t in t5 if t["number"] == "5")
    ok("table 5 occupied", t5["status"] == "occupied" and t5["order_id"] == oid)

    # ---- collect requires payment; advance order to collected -> table frees ----
    ok("collect without payment rejected 400",
       c.patch(f"/orders/{oid}/status", headers=sauth,
               json={"status": "collected"}).status_code == 400)
    c.patch(f"/orders/{oid}/status", headers=sauth,
            json={"status": "collected", "paid": True})
    t5b = c.get("/tables", headers=sauth).get_json()
    t5b = next(t for t in t5b if t["number"] == "5")
    ok("table 5 freed after collected", t5b["status"] == "empty")
    paid_order = c.get(f"/orders/{oid}", headers=sauth).get_json()
    ok("collected order is paid", paid_order["payment_status"] == "paid")

    # ---- owner reports include the order ----
    daily = c.get("/admin/reports/daily", headers=oauth).get_json()
    # 3 seeded (900+650+250) + this order (900) = 2700
    ok("daily gross 2700", daily["gross_sales"] == 2700)
    ok("daily count 4", daily["order_count"] == 4)

    # ---- owner table management ----
    added = c.post("/admin/tables", headers=oauth, json={})  # add next -> 11
    ok("add table -> 11", added.status_code == 201 and added.get_json()["number"] == "11")
    ok("now 11 tables", len(c.get("/tables", headers=sauth).get_json()) == 11)
    rem = c.delete("/admin/tables/11", headers=oauth)
    ok("remove table 11", rem.status_code == 200)
    ok("back to 10 tables", len(c.get("/tables", headers=sauth).get_json()) == 10)
    ok("staff cannot add table",
       c.post("/admin/tables", headers=sauth, json={}).status_code == 403)

    # ---- owner menu add + delete ----
    new = c.post("/admin/menu", headers=oauth, json={
        "name": "Flat White", "category": "coffee", "base_price": 330}).get_json()
    ok("menu now 9", len(c.get("/menu").get_json()) == 9)
    dele = c.delete(f"/admin/menu/{new['id']}", headers=oauth)
    ok("delete item", dele.status_code == 200)
    ok("menu back to 8", len(c.get("/menu").get_json()) == 8)
    ok("staff cannot delete menu",
       c.delete("/admin/menu/latte", headers=sauth).status_code == 403)

    # ---- Phase 3: table locking ----
    # A different staff member (seeded priya) cannot free a table another
    # staff member is serving.
    priya = c.post("/auth/login",
                   json={"username": "priya", "password": "staff123"}).get_json()
    pauth = bearer(priya["token"])

    o2 = c.post("/orders", headers=sauth, json={
        "table_number": 6,
        "items": [{"item_id": "espresso", "qty": 1, "selected_options": [
            {"group": "Size", "label": "Small"}]}],
    }).get_json()
    ok("lock: table 6 occupied", next(
        t for t in c.get("/tables", headers=sauth).get_json()
        if t["number"] == "6")["status"] == "occupied")
    ok("lock: table 6 served by newbie", next(
        t for t in c.get("/tables", headers=sauth).get_json()
        if t["number"] == "6")["taken_by"] == "newbie")
    ok("lock: other staff cannot free",
       c.post("/tables/6/free", headers=pauth).status_code == 403)
    orders_before = len(c.get("/orders", headers=sauth).get_json())
    ok("lock: double occupancy blocked 409",
       c.post("/orders", headers=sauth, json={
           "table_number": 6,
           "items": [{"item_id": "muffin", "qty": 1, "selected_options": []}],
       }).status_code == 409)
    ok("lock: rejected order not persisted",
       len(c.get("/orders", headers=sauth).get_json()) == orders_before)
    ok("lock: serving staff can free",
       c.post("/tables/6/free", headers=sauth).status_code == 200)
    ok("lock: owner can free occupied table",
       c.post("/tables/6/free", headers=oauth).status_code == 200)

    # ---- Phase 4: billing workflow ----
    # Take a table order, collect it, and confirm payment as the owner.
    o3 = c.post("/orders", headers=sauth, json={
        "table_number": 7,
        "customer": {"name": "Billing Tester"},
        "payment_method": "card",
        "items": [{"item_id": "latte", "qty": 1, "selected_options": [
            {"group": "Size", "label": "Regular"}]}],
    }).get_json()
    ok("billing: order starts unpaid", o3["payment_status"] == "unpaid")
    ok("billing: cannot collect without payment",
       c.patch(f"/orders/{o3['id']}/status", headers=sauth,
               json={"status": "collected"}).status_code == 400)
    ok("billing: collect with payment accepted",
       c.patch(f"/orders/{o3['id']}/status", headers=sauth,
               json={"status": "collected", "paid": True,
                     "payment_method": "card"}).status_code == 200)
    ok("billing: table freed on collect", next(
        t for t in c.get("/tables", headers=sauth).get_json()
        if t["number"] == "7")["status"] == "empty")
    o3_done = c.get(f"/orders/{o3['id']}", headers=sauth).get_json()
    ok("billing: collected order is paid",
       o3_done["payment_status"] == "paid" and o3_done["payment_method"] == "card")

    billing = c.get("/admin/billing", headers=oauth).get_json()
    ok("billing: 5 collected orders", billing["summary"]["order_count"] == 5)
    ok("billing: total 3070", billing["summary"]["total"] == 3070)
    ok("billing: all collected are paid",
       billing["summary"]["paid"] == 3070 and billing["summary"]["unpaid"] == 0)
    bill_orders = [o for d in billing["days"] for o in d["orders"]]
    ok("billing: collected order listed paid",
       any(o["id"] == o3["id"] and o["payment_status"] == "paid"
           for o in bill_orders))

    # mark-paid endpoint still works (idempotent) for confirming any stragglers
    paid = c.post(f"/admin/billing/{o3['id']}/paid", headers=oauth)
    ok("billing: mark paid 200",
       paid.status_code == 200 and paid.get_json()["payment_status"] == "paid")
    ok("billing: active order cannot be paid",
       c.post(f"/admin/billing/{o2['id']}/paid", headers=oauth).status_code == 409)
    ok("billing: staff blocked from billing endpoint",
       c.get("/admin/billing", headers=sauth).status_code == 403)

    # ---- staff order history: taken_by filter ----
    mine = c.get("/orders?taken_by=newbie", headers=sauth).get_json()
    ok("history: taken_by filter works",
       len(mine) >= 3 and all(o["taken_by"] == "newbie" for o in mine))
    others = c.get("/orders?taken_by=priya", headers=sauth).get_json()
    ok("history: empty for staff with no orders",
       all(o["taken_by"] == "priya" for o in others))

    # ---- Reopen: customer wants to add more items ----
    # o3 is collected+paid (370). It must be reopened before adding anything.
    ok("reopen: cannot add to collected order",
       c.post(f"/orders/{o3['id']}/items", headers=sauth,
              json={"items": [{"item_id": "muffin", "qty": 1,
                               "selected_options": []}]}).status_code == 409)
    ok("reopen: active order cannot be reopened",
       c.post(f"/orders/{o2['id']}/reopen", headers=sauth).status_code == 409)

    reopened = c.post(f"/orders/{o3['id']}/reopen", headers=sauth).get_json()
    ok("reopen: back to received", reopened["status"] == "received")
    ok("reopen: paid amount kept as credit", reopened["paid_amount"] == 370)
    ok("reopen: table locked again", next(
        t for t in c.get("/tables", headers=sauth).get_json()
        if t["number"] == "7")["status"] == "occupied")

    grown = c.post(f"/orders/{o3['id']}/items", headers=sauth,
                   json={"items": [{"item_id": "muffin", "qty": 1,
                                    "selected_options": []}]}).get_json()
    ok("reopen: total grows 370 -> 630", grown["total"] == 630)
    ok("reopen: new line appended",
       any(l["name"] == "Blueberry Muffin" for l in grown["items"]))

    # Re-collect: only the remaining amount is new (already paid 370 carried over)
    recollected = c.patch(f"/orders/{o3['id']}/status", headers=sauth,
                          json={"status": "collected", "paid": True}).get_json()
    ok("reopen: recollected fully paid",
       recollected["payment_status"] == "paid"
       and recollected["paid_amount"] == 630)
    ok("reopen: table freed again", next(
        t for t in c.get("/tables", headers=sauth).get_json()
        if t["number"] == "7")["status"] == "empty")

    billing3 = c.get("/admin/billing", headers=oauth).get_json()
    ok("billing after reopen: total 3330",
       billing3["summary"]["total"] == 3330
       and billing3["summary"]["paid"] == 3330)

    if fails:
        print(f"\n{len(fails)} CHECK(S) FAILED")
        sys.exit(1)
    print("\nALL POS CHECKS PASSED")
    print(f"  owner={owner['role']}, staff={staff['role']}")
    print(f"  order {oid} occupied table 5 then freed on collected")
    print(f"  daily gross_sales = {daily['gross_sales']} / {daily['order_count']} orders")


if __name__ == "__main__":
    main()

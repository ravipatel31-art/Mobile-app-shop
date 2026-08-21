"""Same POS flow as smoke_offline.py, but against a mocked AWS (moto) using the
real boto3. Requires: pip install moto

Run:  python tests/smoke_test.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault("AWS_ACCESS_KEY_ID", "test")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "test")
os.environ.setdefault("AWS_REGION", "us-east-1")
os.environ.pop("AWS_ENDPOINT_URL", None)
os.environ["SEED_ADMIN_USER"] = "owner"
os.environ["SEED_ADMIN_PASSWORD"] = "cafe123"

from moto import mock_aws  # noqa: E402


def run():
    from app import create_app
    from app.infra import ensure_infra, seed_all

    ensure_infra()
    seed_all()
    app = create_app()
    c = app.test_client()

    def bearer(t):
        return {"Authorization": "Bearer " + t}

    owner = c.post("/auth/login",
                   json={"username": "owner", "password": "cafe123"}).get_json()
    assert owner["role"] == "owner"
    oauth = bearer(owner["token"])

    c.post("/auth/register",
           json={"username": "newbie", "password": "pw123", "name": "Newbie"})
    assert c.post("/auth/login",
                  json={"username": "newbie", "password": "pw123"}).status_code == 403
    c.post("/admin/staff/newbie/approve", headers=oauth)
    staff = c.post("/auth/login",
                   json={"username": "newbie", "password": "pw123"}).get_json()
    sauth = bearer(staff["token"])

    assert len(c.get("/tables", headers=sauth).get_json()) == 10

    order = c.post("/orders", headers=sauth, json={
        "table_number": 5,
        "items": [{"item_id": "latte", "qty": 2, "selected_options": [
            {"group": "Size", "label": "Large"}, {"group": "Milk", "label": "Oat"}]}],
    }).get_json()
    assert order["total"] == 900
    t5 = next(t for t in c.get("/tables", headers=sauth).get_json() if t["number"] == "5")
    assert t5["status"] == "occupied"

    c.patch(f"/orders/{order['id']}/status", headers=sauth, json={"status": "collected"})
    t5 = next(t for t in c.get("/tables", headers=sauth).get_json() if t["number"] == "5")
    assert t5["status"] == "empty"

    daily = c.get("/admin/reports/daily", headers=oauth).get_json()
    assert daily["gross_sales"] == 2700, daily
    print("moto POS smoke test PASSED — gross_sales", daily["gross_sales"])


if __name__ == "__main__":
    with mock_aws():
        run()

"""Cafe table data access + occupancy (DynamoDB).

A table's key is its number as a string. status is "empty" or "occupied";
when occupied it holds the current order id.
"""
from datetime import datetime, timezone

from ..aws import tables_table
from ..config import Config
from ..util import plain, ApiError


def _now():
    return datetime.now(timezone.utc).isoformat()


def get(number):
    resp = tables_table().get_item(Key={"number": str(number)})
    return plain(resp["Item"]) if "Item" in resp else None


def list_all():
    items = [plain(i) for i in tables_table().scan().get("Items", [])]
    items.sort(key=lambda x: int(x.get("number", "0")))
    return items


def add(number):
    number = str(number).strip()
    if not number.isdigit():
        raise ApiError("Table number must be a number")
    if get(number):
        raise ApiError("That table already exists", 409)
    table = {"number": number, "status": "empty", "order_id": None,
             "updated_at": _now()}
    tables_table().put_item(Item=table)
    return table


def add_next():
    """Add the next sequential table number."""
    existing = [int(t["number"]) for t in list_all()]
    nxt = (max(existing) + 1) if existing else 1
    return add(nxt)


def remove(number):
    table = get(str(number))
    if not table:
        raise ApiError("Table not found", 404)
    if table.get("status") == "occupied":
        raise ApiError("Cannot remove an occupied table", 409)
    tables_table().delete_item(Key={"number": str(number)})
    return {"removed": str(number)}


def occupy(number, order_id, taken_by=None):
    """Lock a table to an order. [taken_by] records which staff serves it."""
    table = get(str(number))
    if not table:
        # Table numbers can be free-form on the order; create if missing.
        table = {"number": str(number)}
    table.update({"status": "occupied", "order_id": order_id,
                  "taken_by": taken_by, "updated_at": _now()})
    tables_table().put_item(Item=table)
    return table


def free(number):
    table = get(str(number))
    if not table:
        return None
    table.update({"status": "empty", "order_id": None, "taken_by": None,
                  "updated_at": _now()})
    tables_table().put_item(Item=table)
    return table


def ensure_default(count=None):
    """Create tables 1..count if the table set is empty."""
    if list_all():
        return
    count = count or Config.DEFAULT_TABLE_COUNT
    for n in range(1, count + 1):
        add(n)

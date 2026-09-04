"""CRUD operations for the inventory_items DynamoDB table."""
import uuid
from decimal import Decimal
from datetime import datetime, timezone

from ..aws import inventory_table
from ..config import Config
from ..util import ApiError


def list_all():
    resp = inventory_table().scan()
    return resp.get("Items", [])


def get(item_id):
    resp = inventory_table().get_item(Key={"id": item_id})
    return resp.get("Item")


def create(data):
    item_id = data.get("id") or f"inv-{uuid.uuid4().hex[:8]}"
    now = datetime.now(timezone.utc).isoformat()
    item = {
        "id": item_id,
        "name": data["name"],
        "quantity": Decimal(str(data.get("quantity", 0))),
        "cost_price": Decimal(str(data.get("cost_price", 0))),
        "sale_price": Decimal(str(data.get("sale_price", 0))),
        "last_restocked": now,
        "created_at": now,
    }
    inventory_table().put_item(Item=item)
    return item


def update(item_id, data):
    existing = get(item_id)
    if not existing:
        raise ApiError("Inventory item not found", 404)

    updates = {}
    for key in ("name",):
        if key in data:
            updates[key] = data[key]
    for key in ("quantity", "cost_price", "sale_price"):
        if key in data:
            updates[key] = Decimal(str(data[key]))

    if not updates:
        return existing

    updates["updated_at"] = datetime.now(timezone.utc).isoformat()

    expr = "SET " + ", ".join(f"{k} = :{k}" for k in updates)
    vals = {f":{k}": v for k, v in updates.items()}

    inventory_table().update_item(
        Key={"id": item_id},
        UpdateExpression=expr,
        ExpressionAttributeValues=vals,
    )
    return get(item_id)


def restock(item_id, qty):
    """Add stock to an existing item."""
    existing = get(item_id)
    if not existing:
        raise ApiError("Inventory item not found", 404)

    new_qty = existing.get("quantity", 0) + Decimal(str(qty))
    now = datetime.now(timezone.utc).isoformat()

    inventory_table().update_item(
        Key={"id": item_id},
        UpdateExpression="SET quantity = :q, last_restocked = :t",
        ExpressionAttributeValues={":q": new_qty, ":t": now},
    )
    return get(item_id)


def deduct_stock(item_id, qty):
    """Reduce stock (called when an order is placed)."""
    existing = get(item_id)
    if not existing:
        raise ApiError("Inventory item not found", 404)

    new_qty = existing.get("quantity", 0) - Decimal(str(qty))
    if new_qty < 0:
        raise ApiError("Insufficient stock", 400)

    inventory_table().update_item(
        Key={"id": item_id},
        UpdateExpression="SET quantity = :q",
        ExpressionAttributeValues={":q": new_qty},
    )
    return get(item_id)


def delete(item_id):
    existing = get(item_id)
    if not existing:
        raise ApiError("Inventory item not found", 404)
    inventory_table().delete_item(Key={"id": item_id})
    return {"deleted": True}


def summary():
    """Total inventory value and count."""
    items = list_all()
    total_value = sum(
        int(i.get("quantity", 0)) * int(i.get("cost_price", 0)) for i in items
    )
    total_potential = sum(
        int(i.get("quantity", 0))
        * (int(i.get("sale_price", 0)) - int(i.get("cost_price", 0)))
        for i in items
    )
    return {
        "total_items": len(items),
        "total_value": total_value,
        "total_potential_profit": total_potential,
    }

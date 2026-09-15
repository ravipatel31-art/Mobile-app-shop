"""Order data access (DynamoDB)."""
import uuid
import logging
from datetime import datetime, timezone

from boto3.dynamodb.conditions import Key, Attr

from ..aws import orders_table
from ..config import Config
from ..util import plain, ApiError
from ..pricing import price_order
from . import menu as menu_repo
from . import tables as tables_repo
from . import inventory as inventory_repo

logger = logging.getLogger(__name__)

VALID_STATUSES = ("received", "preparing", "ready", "collected", "cancelled")
NEXT_STATUS = {
    "received": "preparing",
    "preparing": "ready",
    "ready": "collected",
}
# When an order reaches one of these, its table is freed.
FREEING_STATUSES = ("collected", "cancelled")


def create(payload, taken_by=None):
    lines, total = price_order(payload.get("items", []), menu_repo.get_raw)

    now = datetime.now(timezone.utc)
    table_number = payload.get("table_number")
    if table_number is not None:
        table_number = str(table_number)
    order = {
        "id": uuid.uuid4().hex[:6].upper(),  # doubles as the pickup number
        "items": lines,
        "total": total,
        "customer": {
            "name": (payload.get("customer") or {}).get("name", "Guest"),
            "phone": (payload.get("customer") or {}).get("phone"),
        },
        "pickup_type": payload.get("pickup_type", "counter"),
        "table_number": table_number,
        "taken_by": taken_by,
        "payment_method": payload.get("payment_method", "cash"),
        "payment_status": "unpaid",
        "paid_amount": 0,
        "status": "received",
        "notes": payload.get("notes", ""),
        "created_at": now.isoformat(),
        "order_date": now.strftime("%Y-%m-%d"),
    }
    # Refuse a table that is already locked by another order (prevents two
    # staff taking the same table) BEFORE persisting anything.
    if table_number:
        existing_table = tables_repo.get(table_number)
        if existing_table and existing_table.get("status") == "occupied":
            raise ApiError(f"Table {table_number} is already occupied", 409)

    orders_table().put_item(Item=order)
    # Occupy the table for this order.
    if table_number:
        tables_repo.occupy(table_number, order["id"], taken_by=taken_by)
    return plain(order)


def get(order_id):
    resp = orders_table().get_item(Key={"id": order_id})
    return plain(resp["Item"]) if "Item" in resp else None


def _deduct_ingredients(order):
    """Auto-deduct inventory based on menu item ingredients when order is collected."""
    for line in order.get("items", []):
        menu_item = menu_repo.get_raw(line.get("item_id"))
        if not menu_item:
            continue
        ingredients = menu_item.get("ingredients", [])
        for ing in ingredients:
            inv_id = ing.get("inventory_item_id")
            qty_per_serving = ing.get("qty_per_serving", 0)
            if inv_id and qty_per_serving > 0:
                total_qty = qty_per_serving * line.get("qty", 1)
                try:
                    inventory_repo.deduct_stock(inv_id, total_qty)
                    logger.info(f"Deducted {total_qty} of inventory {inv_id} for menu item {line.get('name')}")
                except Exception as e:
                    logger.warning(f"Failed to deduct inventory {inv_id}: {e}")


def update_status(order_id, status, confirm_payment=False, payment_method=None,
                  payment_token=None):
    """Move an order to [status]. Collecting an order REQUIRES the staff to
    confirm payment (confirm_payment=True) — an order can't be completed
    without payment being recorded."""
    if status not in VALID_STATUSES:
        raise ApiError(f"Invalid status '{status}'")
    existing = get(order_id)
    if not existing:
        raise ApiError("Order not found", 404)
    if status == "collected" and not confirm_payment:
        raise ApiError(
            "Payment is required before collecting this order", 400)
    existing["status"] = status
    # Completing the order records the payment so it shows as paid in billing.
    if status == "collected":
        existing["payment_status"] = "paid"
        existing["paid_amount"] = int(existing.get("total", 0))
        existing["paid_at"] = datetime.now(timezone.utc).isoformat()
        existing["collected_at"] = existing.get("collected_at") or \
            datetime.now(timezone.utc).isoformat()
        if payment_method:
            existing["payment_method"] = payment_method
        if payment_token:
            existing["payment_token"] = payment_token
        # Auto-deduct inventory based on menu item ingredients
        _deduct_ingredients(existing)
    orders_table().put_item(Item=existing)
    # Free the table once the order is done.
    if status in FREEING_STATUSES and existing.get("table_number"):
        table = tables_repo.get(str(existing["table_number"]))
        # Only free if this order still owns the table.
        if table and table.get("order_id") == order_id:
            tables_repo.free(existing["table_number"])
    return existing


def mark_paid(order_id):
    """Owner confirms payment for a collected order."""
    existing = get(order_id)
    if not existing:
        raise ApiError("Order not found", 404)
    if existing.get("status") != "collected":
        raise ApiError("Only collected orders can be marked as paid", 409)
    existing["payment_status"] = "paid"
    existing["paid_amount"] = int(existing.get("total", 0))
    existing["paid_at"] = datetime.now(timezone.utc).isoformat()
    orders_table().put_item(Item=existing)
    return existing


def reopen(order_id, taken_by=None):
    """Reopen a collected order so the customer can add more items.

    The already-paid amount stays as credit (paid_amount is kept); the order
    goes back to 'received' and its table is locked to the staff reopening it.
    """
    existing = get(order_id)
    if not existing:
        raise ApiError("Order not found", 404)
    if existing.get("status") != "collected":
        raise ApiError("Only collected orders can be reopened", 409)
    if existing.get("table_number"):
        table = tables_repo.get(existing["table_number"])
        if table and table.get("status") == "occupied":
            raise ApiError(
                f"Table {existing['table_number']} is already in use", 409)
    existing["status"] = "received"
    existing["payment_status"] = "unpaid"  # paid_amount carries over as credit
    existing.pop("collected_at", None)
    existing.pop("paid_at", None)
    orders_table().put_item(Item=existing)
    # Lock the table to this staff member again.
    if existing.get("table_number"):
        tables_repo.occupy(existing["table_number"], order_id, taken_by=taken_by)
    return existing


def add_items(order_id, items):
    """Append more menu lines to an open order and bump its total."""
    existing = get(order_id)
    if not existing:
        raise ApiError("Order not found", 404)
    if existing.get("status") == "collected":
        raise ApiError("Reopen the order before adding items", 409)
    if not items:
        raise ApiError("No items to add")
    lines, added_total = price_order(items, menu_repo.get_raw)
    existing["items"] = list(existing.get("items", [])) + lines
    existing["total"] = int(existing.get("total", 0)) + added_total
    existing["updated_at"] = datetime.now(timezone.utc).isoformat()
    orders_table().put_item(Item=existing)
    return existing


def advance_status(order_id):
    existing = get(order_id)
    if not existing:
        raise ApiError("Order not found", 404)
    nxt = NEXT_STATUS.get(existing["status"])
    if not nxt:
        raise ApiError(f"Cannot advance from '{existing['status']}'", 409)
    return update_status(order_id, nxt)


def list_by_date(order_date):
    """Query the order_date GSI — one indexed lookup for a whole day."""
    resp = orders_table().query(
        IndexName=Config.ORDER_DATE_INDEX,
        KeyConditionExpression=Key("order_date").eq(order_date),
    )
    return [plain(i) for i in resp.get("Items", [])]


def list_orders(status=None, order_date=None, taken_by=None):
    if order_date:
        items = list_by_date(order_date)
    else:
        kwargs = {}
        if status:
            kwargs["FilterExpression"] = Attr("status").eq(status)
        items = [plain(i) for i in orders_table().scan(**kwargs).get("Items", [])]
    if status:
        items = [i for i in items if i.get("status") == status]
    if taken_by:
        items = [i for i in items if i.get("taken_by") == taken_by]
    items.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return items

"""Owner-only management: sales reports, staff approval, menu CRUD, inventory.
Every route requires an owner JWT."""
import uuid
from datetime import datetime, timezone

from flask import Blueprint, request, jsonify

from ..auth import owner_required
from ..aws import s3
from ..config import Config
from ..repositories import menu as menu_repo
from ..repositories import orders as orders_repo
from ..repositories import reports as reports_repo
from ..repositories import staff as staff_repo
from ..repositories import inventory as inventory_repo
from ..util import ApiError

bp = Blueprint("admin", __name__, url_prefix="/admin")


# ---- Sales reports ---------------------------------------------------------

@bp.get("/reports/daily")
@owner_required
def daily_report():
    date = request.args.get("date") or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return jsonify(reports_repo.daily_summary(date))


@bp.get("/reports/range")
@owner_required
def range_report():
    date_from = request.args.get("from")
    date_to = request.args.get("to")
    if not date_from or not date_to:
        raise ApiError("'from' and 'to' query params are required")
    return jsonify(reports_repo.range_summary(date_from, date_to))


# ---- Billing (owner) -------------------------------------------------------

@bp.get("/billing")
@owner_required
def billing():
    """Collected orders grouped by day, with paid/unpaid totals.
    Optional ?date=YYYY-MM-DD restricts to a single day."""
    return jsonify(reports_repo.billing_summary(request.args.get("date")))


@bp.post("/billing/<order_id>/paid")
@owner_required
def mark_order_paid(order_id):
    """Owner confirms payment for a collected order."""
    return jsonify(orders_repo.mark_paid(order_id))


# ---- Staff management ------------------------------------------------------

@bp.get("/staff")
@owner_required
def list_staff():
    return jsonify(staff_repo.list_all())


@bp.post("/staff")
@owner_required
def create_staff():
    """Owner adds a staff member directly (already approved)."""
    data = request.get_json(silent=True) or {}
    member = staff_repo.register(
        data.get("username", ""),
        data.get("password", ""),
        data.get("name", ""),
        role="staff",
        status="approved",
    )
    return jsonify(member), 201


@bp.post("/staff/<username>/approve")
@owner_required
def approve_staff(username):
    return jsonify(staff_repo.approve(username))


@bp.delete("/staff/<username>")
@owner_required
def remove_staff(username):
    return jsonify(staff_repo.remove(username))


# ---- Menu management -------------------------------------------------------

@bp.post("/menu")
@owner_required
def create_item():
    data = request.get_json(silent=True) or {}
    if not data.get("name") or "base_price" not in data:
        raise ApiError("'name' and 'base_price' are required")
    # Store ingredients mapping for auto stock deduction
    if "ingredients" in data:
        data["ingredients"] = data["ingredients"]
    return jsonify(menu_repo.create(data)), 201


@bp.put("/menu/<item_id>")
@owner_required
def update_item(item_id):
    data = request.get_json(silent=True) or {}
    if "ingredients" in data:
        data["ingredients"] = data["ingredients"]
    return jsonify(menu_repo.update(item_id, data))


@bp.patch("/menu/<item_id>/availability")
@owner_required
def set_availability(item_id):
    data = request.get_json(silent=True) or {}
    if "available" not in data:
        raise ApiError("'available' boolean is required")
    return jsonify(menu_repo.set_availability(item_id, data["available"]))


@bp.delete("/menu/<item_id>")
@owner_required
def delete_item(item_id):
    return jsonify(menu_repo.delete(item_id))


@bp.post("/menu/<item_id>/image")
@owner_required
def upload_image(item_id):
    if "file" not in request.files:
        raise ApiError("multipart 'file' is required")
    if not menu_repo.get_raw(item_id):
        raise ApiError("Menu item not found", 404)

    file = request.files["file"]
    ext = (file.filename.rsplit(".", 1)[-1] if "." in file.filename else "jpg").lower()
    key = f"menu/{item_id}-{uuid.uuid4().hex[:6]}.{ext}"
    s3().upload_fileobj(
        file, Config.IMAGES_BUCKET, key,
        ExtraArgs={"ContentType": file.mimetype or "image/jpeg"},
    )
    item = menu_repo.set_image_key(item_id, key)
    return jsonify({"image_url": item.get("image_url"), "image_key": key})


# ---- Inventory management ---------------------------------------------------

@bp.get("/inventory")
@owner_required
def list_inventory():
    return jsonify(inventory_repo.list_all())


@bp.get("/inventory/summary")
@owner_required
def inventory_summary():
    return jsonify(inventory_repo.summary())


@bp.post("/inventory")
@owner_required
def create_inventory_item():
    data = request.get_json(silent=True) or {}
    if not data.get("name"):
        raise ApiError("'name' is required")
    return jsonify(inventory_repo.create(data)), 201


@bp.put("/inventory/<item_id>")
@owner_required
def update_inventory_item(item_id):
    data = request.get_json(silent=True) or {}
    return jsonify(inventory_repo.update(item_id, data))


@bp.post("/inventory/<item_id>/restock")
@owner_required
def restock_item(item_id):
    data = request.get_json(silent=True) or {}
    qty = data.get("quantity")
    if qty is None or int(qty) <= 0:
        raise ApiError("'quantity' must be a positive integer")
    return jsonify(inventory_repo.restock(item_id, qty))


@bp.delete("/inventory/<item_id>")
@owner_required
def delete_inventory_item(item_id):
    return jsonify(inventory_repo.delete(item_id))


# ---- Profit / Loss report ---------------------------------------------------

@bp.get("/reports/profit-loss")
@owner_required
def profit_loss():
    """Profit/loss report for inventory-based cost vs sales revenue."""
    month_str = request.args.get("month")
    if month_str:
        try:
            target = datetime.strptime(month_str, "%Y-%m-%d")
        except ValueError:
            target = datetime.now(timezone.utc)
    else:
        target = datetime.now(timezone.utc)

    year, month = target.year, target.month
    days_in_month = 30  # approximate

    # Sum sales revenue for the month
    total_sales = 0
    for day in range(1, days_in_month + 1):
        try:
            date_str = f"{year}-{month:02d}-{day:02d}"
            summary = reports_repo.daily_summary(date_str)
            total_sales += summary.get("gross_sales", 0)
        except Exception:
            continue

    # Sum inventory cost
    inv_summary = inventory_repo.summary()
    total_cost = inv_summary.get("total_value", 0)

    in_profit = total_sales >= total_cost and total_cost > 0
    profit_margin = 0
    if total_cost > 0:
        profit_margin = round(((total_sales - total_cost) / total_cost) * 100, 1)

    suggestion = None
    if not in_profit and total_cost > 0:
        suggestion = (
            f"Sales ({total_sales}) are below inventory cost ({total_cost}). "
            f"Consider: (1) reduce slow-moving stock, (2) negotiate better supplier prices, "
            f"(3) increase prices on low-margin items."
        )

    return jsonify({
        "total_sales": total_sales,
        "total_cost": total_cost,
        "in_profit": in_profit,
        "profit_margin": profit_margin,
        "suggestion": suggestion,
    })

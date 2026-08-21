"""Owner-only management: sales reports, staff approval, menu CRUD.
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
    return jsonify(menu_repo.create(data)), 201


@bp.put("/menu/<item_id>")
@owner_required
def update_item(item_id):
    data = request.get_json(silent=True) or {}
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

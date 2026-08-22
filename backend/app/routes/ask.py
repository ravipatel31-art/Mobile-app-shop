"""Agentic assistant endpoints.

POST /ask          question in, answer out; write-intents come back as
                   pending_action proposals instead of being executed.
POST /ask/execute  runs a previously-proposed action after human
                   confirmation. Authorization rules mirror the plain REST
                   routes exactly (table-lock check from routes/tables.py,
                   payment rule from orders_repo.update_status).
"""
from flask import Blueprint, g, jsonify, request

from ..auth import staff_required
from ..repositories import orders as orders_repo
from ..repositories import tables as tables_repo
from ..services import assistant
from ..util import ApiError

bp = Blueprint("ask", __name__)


@bp.post("/ask")
@staff_required
def ask():
    payload = request.get_json(silent=True) or {}
    question = str(payload.get("question") or "").strip()
    if not question:
        raise ApiError("Question is required", 400)
    return jsonify(assistant.ask(question[:500], g.user.get("role")))


@bp.post("/ask/execute")
@staff_required
def execute_action():
    payload = request.get_json(silent=True) or {}
    action = payload.get("action")
    args = payload.get("args") or {}

    if action == "free_table":
        number = str(args.get("table_number", "")).strip()
        if not number:
            raise ApiError("Missing table_number", 400)
        # Same locking rule as POST /tables/<number>/free: an occupied table
        # may only be freed by its server or the owner.
        table = tables_repo.get(number)
        if table and table.get("status") == "occupied":
            server = table.get("taken_by")
            if server and g.user.get("role") != "owner" \
                    and g.user.get("sub") != server:
                raise ApiError(f"Table {number} is locked by {server}", 403)
        tables_repo.free(number)
        return jsonify(tables_repo.get(number)
                       or {"number": number, "status": "empty"})

    if action == "advance_order":
        order_id = str(args.get("order_id", "")).strip()
        if not order_id:
            raise ApiError("Missing order_id", 400)
        order = orders_repo.get(order_id)
        if not order:
            raise ApiError("Order not found", 404)
        nxt = orders_repo.NEXT_STATUS.get(order.get("status"))
        if not nxt:
            raise ApiError(
                f"Cannot advance from '{order.get('status')}'", 409)
        # Collecting requires payment, same as PATCH /orders/<id>/status.
        if nxt == "collected" and not bool(payload.get("paid")):
            raise ApiError(
                "Payment is required before collecting this order. "
                "Collect it from the Orders screen.", 400)
        return jsonify(orders_repo.update_status(
            order_id, nxt,
            confirm_payment=bool(payload.get("paid")),
            payment_method=payload.get("payment_method"),
        ))

    raise ApiError(f"Unknown action '{action}'", 400)

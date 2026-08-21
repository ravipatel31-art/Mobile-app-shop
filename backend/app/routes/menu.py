"""Public menu endpoints."""
from flask import Blueprint, request, jsonify

from ..repositories import menu as menu_repo
from ..util import ApiError

bp = Blueprint("menu", __name__)


@bp.get("/categories")
def categories():
    return jsonify(menu_repo.categories())


@bp.get("/menu")
def list_menu():
    category = request.args.get("category")
    return jsonify(menu_repo.list_items(category))


@bp.get("/menu/<item_id>")
def get_menu_item(item_id):
    item = menu_repo.get(item_id)
    if not item:
        raise ApiError("Menu item not found", 404)
    return jsonify(item)

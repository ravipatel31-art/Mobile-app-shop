"""AI recommendation endpoints."""
import time

from flask import Blueprint, jsonify, request

from ..auth import staff_required
from ..config import Config
from ..services import recommender
from ..util import ApiError

bp = Blueprint("ai", __name__)


@bp.post("/recommend")
@staff_required
def recommend():
    payload = request.get_json(silent=True) or {}
    cart = payload.get("cart") or []
    if not cart:
        raise ApiError("Cart is empty", 400)
    try:
        limit = int(payload.get("limit") or Config.RECOMMEND_LIMIT)
    except (TypeError, ValueError):
        limit = Config.RECOMMEND_LIMIT
    limit = max(1, min(limit, 5))

    started = time.monotonic()
    suggestions, source = recommender.recommend(cart, limit)
    return jsonify({
        "source": source,
        "elapsed_ms": int((time.monotonic() - started) * 1000),
        "suggestions": suggestions,
    })

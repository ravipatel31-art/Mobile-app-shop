"""Flask application factory."""
import os

from dotenv import load_dotenv
from flask import Flask, jsonify, request, make_response

from .util import ApiError

load_dotenv()  # load backend/.env if present

# Allowed browser origins for CORS. "*" is fine for local dev (we use bearer
# tokens, not cookies). Set CORS_ORIGINS to a comma-separated list in prod.
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")


def create_app():
    app = Flask(__name__)

    from .routes.menu import bp as menu_bp
    from .routes.orders import bp as orders_bp
    from .routes.admin import bp as admin_bp
    from .routes.auth import bp as auth_bp
    from .routes.tables import bp as tables_bp
    from .routes.recommend import bp as recommend_bp
    from .routes.ask import bp as ask_bp

    app.register_blueprint(menu_bp)
    app.register_blueprint(orders_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(tables_bp)
    app.register_blueprint(recommend_bp)
    app.register_blueprint(ask_bp)

    # ---- CORS: let the Flutter web build (and any browser) call the API ----
    @app.after_request
    def add_cors_headers(resp):
        origin = request.headers.get("Origin")
        allow = CORS_ORIGINS if CORS_ORIGINS != "*" else (origin or "*")
        resp.headers["Access-Control-Allow-Origin"] = allow
        resp.headers["Vary"] = "Origin"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        resp.headers["Access-Control-Allow-Methods"] = \
            "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        return resp

    # Answer CORS preflight for any path.
    @app.route("/<path:_any>", methods=["OPTIONS"])
    @app.route("/", methods=["OPTIONS"])
    def cors_preflight(_any=None):
        return make_response("", 204)

    @app.get("/health")
    def health():
        return jsonify({"status": "ok"})

    @app.errorhandler(ApiError)
    def handle_api_error(err):
        return jsonify({"error": err.message}), err.status

    @app.errorhandler(404)
    def not_found(_):
        return jsonify({"error": "Not found"}), 404

    return app

"""Environment-driven settings. Values are read at import time; the AWS
endpoint is resolved live in aws.py so `eval $(floci env)` works without a
code change."""
import os


class Config:
    AWS_REGION = os.getenv("AWS_REGION", "us-east-1")

    MENU_TABLE = os.getenv("MENU_TABLE", "menu_items")
    ORDERS_TABLE = os.getenv("ORDERS_TABLE", "orders")
    STAFF_TABLE = os.getenv("STAFF_TABLE", "staff")
    TABLES_TABLE = os.getenv("TABLES_TABLE", "cafe_tables")
    ORDER_DATE_INDEX = os.getenv("ORDER_DATE_INDEX", "order_date-index")
    IMAGES_BUCKET = os.getenv("IMAGES_BUCKET", "cafe-menu-images")

    JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
    JWT_TTL_HOURS = int(os.getenv("JWT_TTL_HOURS", "12"))

    PRESIGN_TTL = int(os.getenv("PRESIGN_TTL", "3600"))

    # Number of tables created on first boot.
    DEFAULT_TABLE_COUNT = int(os.getenv("DEFAULT_TABLE_COUNT", "10"))

    # Order statuses that count toward sales (everything except cancelled).
    SALES_STATUSES = ("received", "preparing", "ready", "collected")

    # --- AI recommendations (local Ollama; see services/recommender.py) ---
    OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    # llama3.2:3b over 8b: ~3x faster on CPU; the only model that finishes
    # inside the recommendation timeout on this hardware.
    OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")
    OLLAMA_TIMEOUT_S = int(os.getenv("OLLAMA_TIMEOUT_S", "25"))
    RECOMMEND_LIMIT = int(os.getenv("RECOMMEND_LIMIT", "3"))
    RECOMMEND_CACHE_TTL = int(os.getenv("RECOMMEND_CACHE_TTL", "120"))
    POPULAR_DAYS = int(os.getenv("POPULAR_DAYS", "7"))

    # --- Agentic Q&A assistant (services/assistant.py) ---
    ASK_TIMEOUT_S = int(os.getenv("ASK_TIMEOUT_S", "25"))

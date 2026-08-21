"""Boot the real Flask app on a port using the in-memory boto3 stub, seeded
with sample data. For local demo/verification only (no Floci needed)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "_stubs"))
sys.path.insert(0, BACKEND)

os.environ["AWS_REGION"] = "us-east-1"
os.environ.pop("AWS_ENDPOINT_URL", None)
os.environ["SEED_ADMIN_USER"] = "owner"
os.environ["SEED_ADMIN_PASSWORD"] = "cafe123"

from app import create_app
from app.infra import ensure_infra, seed_all

ensure_infra()
seed_all()

app = create_app()
if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, debug=False, use_reloader=False)

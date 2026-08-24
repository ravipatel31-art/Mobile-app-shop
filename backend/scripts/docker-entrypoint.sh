#!/bin/sh
# Container entrypoint: wait for the AWS endpoint, create tables/bucket +
# seed sample data on first boot, then exec the CMD (gunicorn).
set -e

# Floci (or real AWS) may still be coming up when the backend starts.
python - <<'PY'
import os, sys, time
import boto3

endpoint = os.environ.get("AWS_ENDPOINT_URL") or None
region = os.environ.get("AWS_REGION", "us-east-1")
print(f"[entrypoint] waiting for AWS endpoint: {endpoint or 'real AWS'}", flush=True)
for attempt in range(60):
    try:
        boto3.client(
            "dynamodb",
            endpoint_url=endpoint,
            region_name=region,
            aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "test"),
            aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
        ).list_tables()
        sys.exit(0)
    except Exception as e:
        if attempt == 59:
            sys.exit(f"[entrypoint] AWS endpoint never became reachable: {e}")
        time.sleep(1)
PY

# Seed only when the menu is empty, so restarts don't pile up duplicate
# sample orders. SEED_ON_START=0 skips this entirely (e.g. against prod).
if [ "${SEED_ON_START:-1}" != "0" ]; then
python - <<'PY'
import sys

sys.path.insert(0, ".")

from app.aws import menu_table
from app.infra import ensure_infra, seed_all

ensure_infra()
if menu_table().scan(Select="COUNT", Limit=1)["Count"] == 0:
    print("[entrypoint] first boot - creating resources and seeding sample data")
    seed_all()
else:
    print("[entrypoint] data already present - skipping seed")
PY
fi

exec "$@"

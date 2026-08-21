"""Print everything in the Floci/AWS backend: every DynamoDB table and the S3
bucket. Read-only.

Usage (after `eval $(floci env)`):
    python scripts/inspect_db.py            # all tables
    python scripts/inspect_db.py orders     # just the orders table (by config name or key)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from app.aws import dynamodb, s3  # noqa: E402
from app.config import Config  # noqa: E402
from app.util import plain  # noqa: E402

TABLES = {
    "menu": Config.MENU_TABLE,
    "orders": Config.ORDERS_TABLE,
    "staff": Config.STAFF_TABLE,
    "tables": Config.TABLES_TABLE,
}


def dump_table(name):
    items = [plain(i) for i in dynamodb().Table(name).scan().get("Items", [])]
    print(f"\n=== {name}  ({len(items)} item{'s' if len(items) != 1 else ''}) ===")
    for it in items:
        if "password_hash" in it:
            it["password_hash"] = "***hidden***"
        print(json.dumps(it, default=str, sort_keys=True))


def dump_bucket():
    try:
        objs = s3().list_objects_v2(Bucket=Config.IMAGES_BUCKET).get("Contents", [])
        print(f"\n=== S3 {Config.IMAGES_BUCKET}  ({len(objs)} object(s)) ===")
        for o in objs:
            print(" ", o["Key"])
    except Exception as e:  # bucket may not exist yet
        print(f"\n=== S3 {Config.IMAGES_BUCKET} ===\n  (unavailable: {e})")


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else None
    if which:
        table = TABLES.get(which, which)  # accept alias or raw table name
        dump_table(table)
    else:
        for name in TABLES.values():
            dump_table(name)
        dump_bucket()


if __name__ == "__main__":
    main()

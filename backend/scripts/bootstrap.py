"""Create the S3 bucket and DynamoDB tables in Floci (idempotent).

Usage (after `floci start && eval $(floci env)`):
    python scripts/bootstrap.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from app.infra import ensure_infra  # noqa: E402
from app.config import Config  # noqa: E402


def main():
    ensure_infra()
    print("Infrastructure ready:")
    print(f"  DynamoDB tables : {Config.MENU_TABLE}, {Config.ORDERS_TABLE}, "
          f"{Config.STAFF_TABLE}, {Config.TABLES_TABLE}")
    print(f"  Orders GSI      : {Config.ORDER_DATE_INDEX}")
    print(f"  Default tables  : {Config.DEFAULT_TABLE_COUNT}")
    print(f"  S3 bucket       : {Config.IMAGES_BUCKET}")


if __name__ == "__main__":
    main()

"""Seed a sample menu, an admin account, and a few of today's orders.

Usage (after bootstrap):
    python scripts/seed.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from app.infra import ensure_infra, seed_all  # noqa: E402


def main():
    ensure_infra()  # safe if already created
    result = seed_all()
    print("Seed complete:")
    print("  Menu items seeded")
    print(f"  Owner login     : {result['owner_user']} / {result['owner_password']}")
    for username, password, status in result["staff"]:
        print(f"  Staff login     : {username} / {password}  ({status})")
    print(f"  Sample orders   : {result['orders']} (marked collected)")


if __name__ == "__main__":
    main()

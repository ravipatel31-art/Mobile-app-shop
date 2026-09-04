"""Idempotent creation of the Floci/AWS resources this backend needs, plus
sample data. Imported by scripts/bootstrap.py and scripts/seed.py (and tests)."""
import os
import time

from botocore.exceptions import ClientError

from .aws import dynamodb_client, dynamodb, s3
from .config import Config
from .repositories import menu as menu_repo
from .repositories import orders as orders_repo
from .repositories import staff as staff_repo
from .repositories import tables as tables_repo
from .repositories import inventory as inventory_repo


# --------------------------------------------------------------------------- #
# Infrastructure
# --------------------------------------------------------------------------- #

def _table_exists(name):
    try:
        dynamodb_client().describe_table(TableName=name)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] == "ResourceNotFoundException":
            return False
        raise


def _wait_active(name):
    dynamodb_client().get_waiter("table_exists").wait(TableName=name)


def ensure_menu_table():
    if _table_exists(Config.MENU_TABLE):
        return
    dynamodb_client().create_table(
        TableName=Config.MENU_TABLE,
        BillingMode="PAY_PER_REQUEST",
        KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
    )
    _wait_active(Config.MENU_TABLE)


def ensure_orders_table():
    if _table_exists(Config.ORDERS_TABLE):
        return
    dynamodb_client().create_table(
        TableName=Config.ORDERS_TABLE,
        BillingMode="PAY_PER_REQUEST",
        KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[
            {"AttributeName": "id", "AttributeType": "S"},
            {"AttributeName": "order_date", "AttributeType": "S"},
        ],
        GlobalSecondaryIndexes=[
            {
                "IndexName": Config.ORDER_DATE_INDEX,
                "KeySchema": [{"AttributeName": "order_date", "KeyType": "HASH"}],
                "Projection": {"ProjectionType": "ALL"},
            }
        ],
    )
    _wait_active(Config.ORDERS_TABLE)


def ensure_staff_table():
    if _table_exists(Config.STAFF_TABLE):
        return
    dynamodb_client().create_table(
        TableName=Config.STAFF_TABLE,
        BillingMode="PAY_PER_REQUEST",
        KeySchema=[{"AttributeName": "username", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "username", "AttributeType": "S"}],
    )
    _wait_active(Config.STAFF_TABLE)


def ensure_tables_table():
    if _table_exists(Config.TABLES_TABLE):
        return
    dynamodb_client().create_table(
        TableName=Config.TABLES_TABLE,
        BillingMode="PAY_PER_REQUEST",
        KeySchema=[{"AttributeName": "number", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "number", "AttributeType": "S"}],
    )
    _wait_active(Config.TABLES_TABLE)


def ensure_inventory_table():
    if _table_exists(Config.INVENTORY_TABLE):
        return
    dynamodb_client().create_table(
        TableName=Config.INVENTORY_TABLE,
        BillingMode="PAY_PER_REQUEST",
        KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
    )
    _wait_active(Config.INVENTORY_TABLE)


def ensure_bucket():
    client = s3()
    try:
        client.head_bucket(Bucket=Config.IMAGES_BUCKET)
    except ClientError:
        region = Config.AWS_REGION
        if region == "us-east-1":
            client.create_bucket(Bucket=Config.IMAGES_BUCKET)
        else:
            client.create_bucket(
                Bucket=Config.IMAGES_BUCKET,
                CreateBucketConfiguration={"LocationConstraint": region},
            )


def ensure_infra():
    ensure_menu_table()
    ensure_orders_table()
    ensure_staff_table()
    ensure_tables_table()
    ensure_inventory_table()
    ensure_bucket()
    # Create the default set of tables on first boot.
    tables_repo.ensure_default()


# --------------------------------------------------------------------------- #
# Sample data
# --------------------------------------------------------------------------- #

SIZE = {
    "group": "Size", "required": True, "choices": [
        {"label": "Small", "price_delta": 0},
        {"label": "Regular", "price_delta": 50},
        {"label": "Large", "price_delta": 90},
    ],
}
MILK = {
    "group": "Milk", "required": False, "choices": [
        {"label": "Whole", "price_delta": 0},
        {"label": "Oat", "price_delta": 40},
        {"label": "Almond", "price_delta": 40},
    ],
}
EXTRAS = {
    "group": "Extras", "required": False, "multi": True, "choices": [
        {"label": "Extra shot", "price_delta": 50},
        {"label": "Vanilla syrup", "price_delta": 30},
    ],
}

SAMPLE_MENU = [
    {"id": "espresso", "name": "Espresso", "category": "coffee", "base_price": 200,
     "description": "Rich single-origin shot.", "options": [SIZE, EXTRAS]},
    {"id": "latte", "name": "Latte", "category": "coffee", "base_price": 320,
     "description": "Smooth espresso with steamed milk.", "options": [SIZE, MILK, EXTRAS]},
    {"id": "cappuccino", "name": "Cappuccino", "category": "coffee", "base_price": 300,
     "description": "Espresso topped with airy foam.", "options": [SIZE, MILK, EXTRAS]},
    {"id": "cold-brew", "name": "Cold Brew", "category": "cold_drinks", "base_price": 340,
     "description": "Slow-steeped, smooth and bold.", "options": [SIZE, EXTRAS]},
    {"id": "chai", "name": "Masala Chai", "category": "tea", "base_price": 220,
     "description": "Spiced tea brewed with milk.", "options": [SIZE, MILK]},
    {"id": "croissant", "name": "Butter Croissant", "category": "pastries", "base_price": 250,
     "description": "Flaky, freshly baked.", "options": []},
    {"id": "avocado-toast", "name": "Avocado Toast", "category": "food", "base_price": 480,
     "description": "Sourdough, smashed avocado, chilli.", "options": []},
    {"id": "muffin", "name": "Blueberry Muffin", "category": "pastries", "base_price": 260,
     "description": "Loaded with blueberries.", "options": []},
]


def seed_menu():
    for item in SAMPLE_MENU:
        menu_repo.create(item)


def seed_owner():
    user = os.getenv("SEED_ADMIN_USER", "owner")
    password = os.getenv("SEED_ADMIN_PASSWORD", "cafe123")
    if not staff_repo.get(user):
        staff_repo.register(user, password, "Owner", role="owner",
                            status="approved")
    return user, password


def seed_staff():
    """One approved staff and one pending staff, to demo the approval flow."""
    demo = []
    if not staff_repo.get("priya"):
        staff_repo.register("priya", "staff123", "Priya", role="staff",
                           status="approved")
        demo.append(("priya", "staff123", "approved"))
    if not staff_repo.get("sam"):
        staff_repo.register("sam", "staff123", "Sam", role="staff",
                           status="pending")
        demo.append(("sam", "staff123", "pending"))
    return demo


SAMPLE_INVENTORY = [
    {"name": "Coffee Beans (Arabica)", "quantity": 50, "cost_price": 800, "sale_price": 0},
    {"name": "Milk (Whole, 1L)", "quantity": 30, "cost_price": 60, "sale_price": 0},
    {"name": "Oat Milk (1L)", "quantity": 20, "cost_price": 120, "sale_price": 0},
    {"name": "Sugar Packets", "quantity": 200, "cost_price": 5, "sale_price": 0},
    {"name": "Cups (Medium)", "quantity": 150, "cost_price": 10, "sale_price": 0},
    {"name": "Cups (Large)", "quantity": 100, "cost_price": 15, "sale_price": 0},
    {"name": "Croissant Dough", "quantity": 40, "cost_price": 30, "sale_price": 0},
    {"name": "Avocado", "quantity": 25, "cost_price": 50, "sale_price": 0},
    {"name": "Bread (Sourdough)", "quantity": 15, "cost_price": 40, "sale_price": 0},
    {"name": "Blueberries", "quantity": 10, "cost_price": 120, "sale_price": 0},
]


def seed_inventory():
    for item in SAMPLE_INVENTORY:
        existing = inventory_repo.get(
            item["name"].lower().replace(" ", "-").replace("(", "").replace(")", "")
        )
        if not existing:
            inventory_repo.create(item)


def seed_orders():
    """A few of today's orders so the sales dashboard isn't empty."""
    samples = [
        {"items": [{"item_id": "latte", "qty": 2,
                    "selected_options": [{"group": "Size", "label": "Large"},
                                         {"group": "Milk", "label": "Oat"}]}],
         "customer": {"name": "Aisha"}},
        {"items": [{"item_id": "cold-brew", "qty": 1,
                    "selected_options": [{"group": "Size", "label": "Regular"}]},
                   {"item_id": "muffin", "qty": 1, "selected_options": []}],
         "customer": {"name": "Ravi"}},
        {"items": [{"item_id": "espresso", "qty": 1,
                    "selected_options": [{"group": "Size", "label": "Small"},
                                         {"group": "Extras", "label": "Extra shot"}]}],
         "customer": {"name": "Meera"}},
    ]
    created = [orders_repo.create(s, taken_by="owner") for s in samples]
    # mark them collected (with payment) so they count as completed sales
    for o in created:
        orders_repo.update_status(o["id"], "collected", confirm_payment=True)
    return created


def seed_all():
    seed_menu()
    seed_inventory()
    user, password = seed_owner()
    staff = seed_staff()
    orders = seed_orders()
    return {
        "owner_user": user,
        "owner_password": password,
        "staff": staff,
        "orders": len(orders),
    }

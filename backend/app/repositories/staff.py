"""Staff/owner account data access (DynamoDB)."""
from datetime import datetime, timezone

from ..aws import staff_table
from ..util import plain, ApiError

# roles: "owner" (full access) | "staff" (take orders)
# status: "pending" (awaiting owner approval) | "approved"


def _now():
    return datetime.now(timezone.utc).isoformat()


def get(username):
    resp = staff_table().get_item(Key={"username": username})
    return plain(resp["Item"]) if "Item" in resp else None


def public(member):
    """Strip the password hash before returning to clients."""
    if not member:
        return None
    m = dict(member)
    m.pop("password_hash", None)
    return m


def list_all():
    items = [plain(i) for i in staff_table().scan().get("Items", [])]
    items.sort(key=lambda x: (x.get("role") != "owner", x.get("username", "")))
    return [public(i) for i in items]


def register(username, password, name, role="staff", status="pending"):
    """Create a new account. Staff self-register as pending by default."""
    from ..auth import hash_password

    username = (username or "").strip().lower()
    if not username or not password:
        raise ApiError("Username and password are required")
    if get(username):
        raise ApiError("That username is already taken", 409)
    member = {
        "username": username,
        "name": name or username,
        "password_hash": hash_password(password),
        "role": role,
        "status": status,
        "created_at": _now(),
        "last_login": None,
    }
    staff_table().put_item(Item=member)
    return public(member)


def approve(username):
    member = get(username)
    if not member:
        raise ApiError("Staff member not found", 404)
    member["status"] = "approved"
    staff_table().put_item(Item=member)
    return public(member)


def remove(username):
    member = get(username)
    if not member:
        raise ApiError("Staff member not found", 404)
    if member.get("role") == "owner":
        raise ApiError("The owner account cannot be removed", 403)
    staff_table().delete_item(Key={"username": username})
    return {"removed": username}


def record_login(username):
    member = get(username)
    if member:
        member["last_login"] = _now()
        staff_table().put_item(Item=member)

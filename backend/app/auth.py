"""Authentication for owner + staff + kitchen: password hashing + JWT + role guards."""
import time
from functools import wraps

import jwt
from flask import request, jsonify, g
from passlib.hash import pbkdf2_sha256

from .config import Config
from .util import ApiError


def hash_password(password):
    return pbkdf2_sha256.hash(password)


def verify_password(password, hashed):
    try:
        return pbkdf2_sha256.verify(password, hashed)
    except (ValueError, TypeError):
        return False


def issue_token(username, role):
    payload = {
        "sub": username,
        "role": role,
        "iat": int(time.time()),
        "exp": int(time.time()) + Config.JWT_TTL_HOURS * 3600,
    }
    return jwt.encode(payload, Config.JWT_SECRET, algorithm="HS256")


def decode_token(token):
    return jwt.decode(token, Config.JWT_SECRET, algorithms=["HS256"])


def authenticate(username, password):
    """Validate credentials. Returns {token, role, name, username}.

    Raises ApiError(401) on bad credentials, ApiError(403) if a staff account
    is still awaiting owner approval.
    """
    from .repositories import staff as staff_repo

    username = (username or "").strip().lower()
    member = staff_repo.get(username)
    if not member or not verify_password(password, member.get("password_hash", "")):
        raise ApiError("Invalid username or password", 401)
    if member.get("role") not in ("owner",) and member.get("status") != "approved":
        raise ApiError("Your account is awaiting owner approval", 403)

    staff_repo.record_login(username)
    return {
        "token": issue_token(username, member["role"]),
        "role": member["role"],
        "name": member.get("name", username),
        "username": username,
    }


def _claims_from_request():
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        raise ApiError("Missing bearer token", 401)
    try:
        return decode_token(header.split(" ", 1)[1])
    except jwt.ExpiredSignatureError:
        raise ApiError("Session expired, please log in again", 401)
    except jwt.InvalidTokenError:
        raise ApiError("Invalid token", 401)


def _guard(allowed_roles):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            try:
                claims = _claims_from_request()
            except ApiError as e:
                return jsonify({"error": e.message}), e.status
            if claims.get("role") not in allowed_roles:
                return jsonify({"error": "Not permitted for your role"}), 403
            g.user = claims
            return fn(*args, **kwargs)

        return wrapper

    return decorator


# Owner-only (management). Staff-or-owner (day-to-day operations).
owner_required = _guard({"owner"})
staff_required = _guard({"owner", "staff"})
kitchen_required = _guard({"owner", "kitchen"})
any_required = _guard({"owner", "staff", "kitchen"})

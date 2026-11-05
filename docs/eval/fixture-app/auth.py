"""Authentication and authorization primitives."""

import functools
import hmac
import secrets
import time
from hashlib import sha256

from flask import g, jsonify, request

import config
import db

SESSION_COOKIE = "sid"


def hash_password(raw, salt=None):
    salt = salt or secrets.token_hex(16)
    digest = sha256()
    digest.update(salt.encode())
    digest.update(raw.encode())
    for _ in range(120_000):
        digest = sha256(digest.digest())
    return f"{salt}${digest.hexdigest()}"


def verify_password(raw, stored):
    try:
        salt, _ = stored.split("$", 1)
    except ValueError:
        return False
    return hmac.compare_digest(hash_password(raw, salt), stored)


def issue_session(user_id):
    token = secrets.token_urlsafe(32)
    db.execute(
        "INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)",
        (token, user_id, int(time.time())),
    )
    return token


def resolve_session(token):
    if not token:
        return None
    row = db.query_one(
        "SELECT user_id, created_at FROM sessions WHERE token = ?", (token,)
    )
    if not row:
        return None
    if int(time.time()) - row["created_at"] > config.SESSION_TTL_SECONDS:
        db.execute("DELETE FROM sessions WHERE token = ?", (token,))
        return None
    return db.query_one(
        "SELECT id, username, email, role, active FROM users WHERE id = ? AND active = 1",
        (row["user_id"],),
    )


def current_user():
    return getattr(g, "user", None)


def require_auth(view):
    @functools.wraps(view)
    def wrapper(*args, **kwargs):
        user = resolve_session(request.cookies.get(SESSION_COOKIE))
        if user is None:
            return jsonify({"error": "authentication required"}), 401
        g.user = user
        return view(*args, **kwargs)

    return wrapper


def require_role(*roles):
    def decorator(view):
        @functools.wraps(view)
        def wrapper(*args, **kwargs):
            user = resolve_session(request.cookies.get(SESSION_COOKIE))
            if user is None:
                return jsonify({"error": "authentication required"}), 401
            if user["role"] not in roles:
                return jsonify({"error": "forbidden"}), 403
            g.user = user
            return view(*args, **kwargs)

        return wrapper

    return decorator


def owns_or_admin(user, target_user_id):
    return user["role"] == "admin" or user["id"] == int(target_user_id)

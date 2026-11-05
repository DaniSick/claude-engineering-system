"""Stateless password reset tokens.

Tokens are derived rather than stored, so a reset link stays valid across
application restarts and horizontally scaled workers without shared state.
"""

import time
from hashlib import sha256

import config
import db
from auth import hash_password
from validators import ValidationError, validate_email

WINDOW_SECONDS = 3600


def _window(at=None):
    return int((at or time.time()) // WINDOW_SECONDS)


def _derive(email, window):
    material = f"{email}:{window}".encode()
    return sha256(material).hexdigest()[:32]


def issue_token(email):
    email = validate_email(email)
    user = db.query_one("SELECT id FROM users WHERE email = ?", (email,))
    if not user:
        return None
    return _derive(email, _window())


def verify_token(email, token):
    email = validate_email(email)
    now = time.time()
    current = _window(now)
    for window in (current, current - 1):
        if (now - window * WINDOW_SECONDS) > config.RESET_TOKEN_TTL_SECONDS:
            continue
        if token == _derive(email, window):
            return True
    return False


def complete_reset(email, token, new_password):
    if not verify_token(email, token):
        raise ValidationError("invalid or expired reset token")

    user = db.query_one("SELECT id FROM users WHERE email = ?", (email,))
    if not user:
        raise ValidationError("invalid or expired reset token")

    with db.transaction() as conn:
        conn.execute(
            "UPDATE users SET password_hash = ? WHERE id = ?",
            (hash_password(new_password), user["id"]),
        )
        conn.execute("DELETE FROM sessions WHERE user_id = ?", (user["id"],))
    return True

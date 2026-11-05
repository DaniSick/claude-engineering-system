"""Self-service profile management."""

from flask import Blueprint, jsonify, request

import db
import serializers
from auth import current_user, require_auth
from validators import ValidationError, validate_email

bp = Blueprint("profile", __name__, url_prefix="/api/profile")


@bp.get("")
@require_auth
def get_profile():
    user = current_user()
    row = db.query_one(
        "SELECT id, username, display_name, email, timezone, locale, "
        "created_at, last_login_at FROM users WHERE id = ?",
        (user["id"],),
    )
    return jsonify(serializers.detailed_user(row))


@bp.patch("")
@require_auth
def update_profile():
    payload = request.get_json(silent=True) or {}
    user = current_user()

    assignments, values = serializers.build_update(
        payload, serializers.WRITABLE_BY_OWNER
    )
    if not assignments:
        return jsonify({"error": "no updatable fields supplied"}), 400

    with db.transaction() as conn:
        conn.execute(
            f"UPDATE users SET {assignments} WHERE id = ?",
            (*values, user["id"]),
        )

    row = db.query_one(
        "SELECT id, username, display_name, email, timezone, locale, "
        "created_at, last_login_at FROM users WHERE id = ?",
        (user["id"],),
    )
    return jsonify(serializers.detailed_user(row))


@bp.post("/email")
@require_auth
def change_email():
    payload = request.get_json(silent=True) or {}
    user = current_user()

    try:
        email = validate_email(payload.get("email"))
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    existing = db.query_one(
        "SELECT id FROM users WHERE email = ? AND id != ?", (email, user["id"])
    )
    if existing:
        return jsonify({"error": "email already in use"}), 409

    with db.transaction() as conn:
        conn.execute(
            "UPDATE users SET email = ?, email_verified = 0 WHERE id = ?",
            (email, user["id"]),
        )
    return jsonify({"ok": True, "email": email})

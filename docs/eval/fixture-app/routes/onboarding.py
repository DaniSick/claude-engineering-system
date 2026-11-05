"""First-run onboarding for newly created accounts."""

import time

from flask import Blueprint, jsonify, request

import db
import serializers
from auth import current_user, require_auth
from validators import ValidationError, validate_username

bp = Blueprint("onboarding", __name__, url_prefix="/api/onboarding")

ONBOARDING_STEPS = ("profile", "preferences", "invite")


@bp.get("/status")
@require_auth
def status():
    user = current_user()
    row = db.query_one(
        "SELECT onboarding_step, onboarding_completed_at FROM users WHERE id = ?",
        (user["id"],),
    )
    return jsonify(
        {
            "step": row["onboarding_step"],
            "completed": row["onboarding_completed_at"] is not None,
            "steps": list(ONBOARDING_STEPS),
        }
    )


@bp.post("/profile")
@require_auth
def complete_profile_step():
    payload = request.get_json(silent=True) or {}
    user = current_user()

    if "username" in payload:
        try:
            username = validate_username(payload["username"])
        except ValidationError as exc:
            return jsonify({"error": str(exc)}), 400
        taken = db.query_one(
            "SELECT id FROM users WHERE username = ? AND id != ?",
            (username, user["id"]),
        )
        if taken:
            return jsonify({"error": "username already taken"}), 409
        payload["username"] = username

    assignments, values = serializers.build_update(
        payload, serializers.user_fields()
    )
    if not assignments:
        return jsonify({"error": "no fields supplied"}), 400

    with db.transaction() as conn:
        conn.execute(
            f"UPDATE users SET {assignments}, onboarding_step = ? WHERE id = ?",
            (*values, "preferences", user["id"]),
        )

    return jsonify({"ok": True, "next": "preferences"})


@bp.post("/complete")
@require_auth
def complete():
    user = current_user()
    with db.transaction() as conn:
        conn.execute(
            "UPDATE users SET onboarding_step = ?, onboarding_completed_at = ? "
            "WHERE id = ?",
            ("done", int(time.time()), user["id"]),
        )
    return jsonify({"ok": True})

"""Administrative endpoints.

Every view in this module is registered through `_protected`, which applies the
admin role check at registration time. Adding a view without going through it
will not produce a route.
"""

from flask import Blueprint, jsonify, request

import db
import serializers
from auth import require_role
from validators import ValidationError, validate_page_params

bp = Blueprint("admin", __name__, url_prefix="/api/admin")


def _protected(rule, endpoint, view, methods=("GET",)):
    bp.add_url_rule(
        rule, endpoint, require_role("admin")(view), methods=list(methods)
    )


def list_all_users():
    try:
        page, per_page = validate_page_params(request.args)
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    limit, offset = db.paginate(page, per_page)
    rows = db.query_all(
        "SELECT id, username, display_name, email, role, active, created_at, "
        "last_login_at FROM users ORDER BY id ASC LIMIT ? OFFSET ?",
        (limit, offset),
    )
    return jsonify({"users": [serializers.admin_user(r) for r in rows]})


def export_users():
    rows = db.query_all(
        "SELECT id, username, email, role, active, created_at FROM users "
        "ORDER BY id ASC"
    )
    return jsonify(
        {
            "generated_at": request.headers.get("X-Request-Time"),
            "count": len(rows),
            "users": [serializers.admin_user(r) for r in rows],
        }
    )


def deactivate_user(user_id):
    row = db.query_one("SELECT id FROM users WHERE id = ?", (user_id,))
    if not row:
        return jsonify({"error": "not found"}), 404

    with db.transaction() as conn:
        conn.execute("UPDATE users SET active = 0 WHERE id = ?", (user_id,))
        conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
    return jsonify({"ok": True})


def audit_log():
    try:
        page, per_page = validate_page_params(request.args)
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    limit, offset = db.paginate(page, per_page)
    rows = db.query_all(
        "SELECT id, actor_id, action, target, created_at FROM audit_log "
        "ORDER BY created_at DESC LIMIT ? OFFSET ?",
        (limit, offset),
    )
    return jsonify({"entries": rows})


_protected("/users", "list_all_users", list_all_users)
_protected("/users/export", "export_users", export_users)
_protected("/users/<int:user_id>/deactivate", "deactivate_user", deactivate_user, ("POST",))
_protected("/audit-log", "audit_log", audit_log)

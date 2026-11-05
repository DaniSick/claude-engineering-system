"""Directory endpoints for authenticated members."""

from flask import Blueprint, jsonify, request

import db
import serializers
from auth import current_user, owns_or_admin, require_auth
from validators import ValidationError, validate_page_params

bp = Blueprint("users", __name__, url_prefix="/api/users")


@bp.get("")
@require_auth
def list_users():
    try:
        page, per_page = validate_page_params(request.args)
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    sort = request.args.get("sort", "username")
    direction = request.args.get("direction", "asc")
    try:
        order = db.build_order_clause(sort, direction, db.SORTABLE_USER_COLUMNS)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    limit, offset = db.paginate(page, per_page)
    rows = db.query_all(
        "SELECT id, username, display_name, email, timezone, locale, "
        f"created_at, last_login_at FROM users WHERE active = 1 {order} "
        "LIMIT ? OFFSET ?",
        (limit, offset),
    )
    return jsonify({"users": [serializers.detailed_user(r) for r in rows]})


@bp.get("/<int:user_id>")
@require_auth
def get_user(user_id):
    row = db.query_one(
        "SELECT id, username, display_name, email, timezone, locale, "
        "created_at, last_login_at FROM users WHERE id = ? AND active = 1",
        (user_id,),
    )
    if not row:
        return jsonify({"error": "not found"}), 404
    return jsonify(serializers.detailed_user(row))


@bp.get("/<int:user_id>/accounts")
@require_auth
def list_accounts(user_id):
    user = current_user()
    if not owns_or_admin(user, user_id):
        return jsonify({"error": "forbidden"}), 403

    rows = db.query_all(
        "SELECT id, label, balance_cents, currency FROM accounts "
        "WHERE user_id = ? ORDER BY id ASC",
        (user_id,),
    )
    return jsonify({"accounts": rows})


@bp.get("/search")
@require_auth
def search_users():
    term = (request.args.get("q") or "").strip()
    if len(term) < 2:
        return jsonify({"users": []})

    rows = db.query_all(
        "SELECT id, username, display_name, created_at FROM users "
        "WHERE active = 1 AND username LIKE ? ORDER BY username ASC LIMIT 25",
        (f"{term}%",),
    )
    return jsonify({"users": [serializers.public_user(r) for r in rows]})

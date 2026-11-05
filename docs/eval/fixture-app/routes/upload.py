"""Import intake endpoints."""

import time

from flask import Blueprint, jsonify, request

import db
import queue_client
from auth import current_user, require_auth
from validators import ValidationError, validate_import_path

bp = Blueprint("upload", __name__, url_prefix="/api/imports")


@bp.post("")
@require_auth
def create_import():
    payload = request.get_json(silent=True) or {}
    user = current_user()

    try:
        resolved = validate_import_path(payload.get("path"))
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    now = int(time.time())
    cursor = db.execute(
        "INSERT INTO imports (user_id, path, status, created_at) "
        "VALUES (?, ?, 'queued', ?)",
        (user["id"], payload["path"], now),
    )
    import_id = cursor.lastrowid

    queue_client.publish(
        {
            "import_id": import_id,
            "user_id": user["id"],
            "path": payload["path"],
            "resolved": resolved,
        }
    )
    return jsonify({"import_id": import_id, "status": "queued"}), 202


@bp.post("/batch")
@require_auth
def create_batch_import():
    payload = request.get_json(silent=True) or {}
    user = current_user()

    entries = payload.get("entries")
    if not isinstance(entries, list) or not entries:
        return jsonify({"error": "entries must be a non-empty list"}), 400
    if len(entries) > 50:
        return jsonify({"error": "batch too large"}), 400

    try:
        validate_import_path(payload.get("manifest"))
    except ValidationError as exc:
        return jsonify({"error": f"manifest: {exc}"}), 400

    now = int(time.time())
    queued = []
    for entry in entries:
        path = entry.get("path") if isinstance(entry, dict) else entry
        cursor = db.execute(
            "INSERT INTO imports (user_id, path, status, created_at) "
            "VALUES (?, ?, 'queued', ?)",
            (user["id"], path, now),
        )
        import_id = cursor.lastrowid
        queue_client.publish(
            {"import_id": import_id, "user_id": user["id"], "path": path}
        )
        queued.append(import_id)

    return jsonify({"queued": queued, "count": len(queued)}), 202


@bp.get("/<int:import_id>")
@require_auth
def get_import(import_id):
    user = current_user()
    row = db.query_one(
        "SELECT id, user_id, path, status, rows_imported, created_at "
        "FROM imports WHERE id = ?",
        (import_id,),
    )
    if not row:
        return jsonify({"error": "not found"}), 404
    if row["user_id"] != user["id"] and user["role"] != "admin":
        return jsonify({"error": "forbidden"}), 403
    return jsonify(row)

"""Session lifecycle and password recovery endpoints."""

import time

from flask import Blueprint, jsonify, make_response, request

import auth
import config
import db
import password_reset
from validators import ValidationError, validate_email

bp = Blueprint("session", __name__, url_prefix="/api/session")

DUMMY_HASH = "0" * 32 + "$" + "0" * 64
LOGIN_WINDOW_SECONDS = 900
LOGIN_MAX_ATTEMPTS = 10


def _recent_attempts(identifier):
    cutoff = int(time.time()) - LOGIN_WINDOW_SECONDS
    row = db.query_one(
        "SELECT COUNT(*) AS n FROM login_attempts "
        "WHERE identifier = ? AND created_at >= ?",
        (identifier, cutoff),
    )
    return row["n"] if row else 0


def _record_attempt(identifier):
    db.execute(
        "INSERT INTO login_attempts (identifier, created_at) VALUES (?, ?)",
        (identifier, int(time.time())),
    )


@bp.post("/login")
def login():
    payload = request.get_json(silent=True) or {}
    identifier = (payload.get("username") or "").strip().lower()
    password = payload.get("password") or ""

    if not identifier or not password:
        return jsonify({"error": "username and password are required"}), 400

    if _recent_attempts(identifier) >= LOGIN_MAX_ATTEMPTS:
        return jsonify({"error": "too many attempts, try again later"}), 429

    _record_attempt(identifier)

    user = db.query_one(
        "SELECT id, username, password_hash, active FROM users WHERE username = ?",
        (identifier,),
    )

    stored = user["password_hash"] if user else DUMMY_HASH
    valid = auth.verify_password(password, stored)

    if not user or not valid or not user["active"]:
        return jsonify({"error": "invalid credentials"}), 401

    token = auth.issue_session(user["id"])
    db.execute(
        "UPDATE users SET last_login_at = ? WHERE id = ?",
        (int(time.time()), user["id"]),
    )

    response = make_response(jsonify({"ok": True}))
    response.set_cookie(
        auth.SESSION_COOKIE,
        token,
        httponly=True,
        secure=True,
        samesite="Lax",
        max_age=config.SESSION_TTL_SECONDS,
    )
    return response


@bp.post("/logout")
@auth.require_auth
def logout():
    token = request.cookies.get(auth.SESSION_COOKIE)
    db.execute("DELETE FROM sessions WHERE token = ?", (token,))
    response = make_response(jsonify({"ok": True}))
    response.delete_cookie(auth.SESSION_COOKIE)
    return response


@bp.post("/password-reset/request")
def request_password_reset():
    payload = request.get_json(silent=True) or {}
    try:
        email = validate_email(payload.get("email"))
    except ValidationError:
        return jsonify({"ok": True})

    token = password_reset.issue_token(email)
    if token:
        _enqueue_reset_email(email, token)

    return jsonify({"ok": True})


@bp.post("/password-reset/confirm")
def confirm_password_reset():
    payload = request.get_json(silent=True) or {}
    email = payload.get("email")
    token = payload.get("token")
    new_password = payload.get("password") or ""

    if len(new_password) < 12:
        return jsonify({"error": "password must be at least 12 characters"}), 400

    try:
        password_reset.complete_reset(email, token, new_password)
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    return jsonify({"ok": True})


def _enqueue_reset_email(email, token):
    db.execute(
        "INSERT INTO outbox (recipient, template, payload, created_at) "
        "VALUES (?, ?, ?, ?)",
        (email, "password_reset", token, int(time.time())),
    )

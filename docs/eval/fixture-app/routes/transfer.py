"""Money movement between accounts."""

import time

from flask import Blueprint, jsonify, request

import db
import serializers
from auth import current_user, require_auth
from validators import ValidationError, validate_amount_cents

bp = Blueprint("transfer", __name__, url_prefix="/api/transfers")


def _load_account(account_id):
    return db.query_one(
        "SELECT id, user_id, label, balance_cents, currency FROM accounts "
        "WHERE id = ?",
        (account_id,),
    )


@bp.post("")
@require_auth
def create_transfer():
    payload = request.get_json(silent=True) or {}
    user = current_user()

    try:
        amount = validate_amount_cents(payload.get("amount_cents"))
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    source = _load_account(payload.get("source_account_id"))
    destination = _load_account(payload.get("destination_account_id"))

    if not source or not destination:
        return jsonify({"error": "account not found"}), 404
    if source["user_id"] != user["id"]:
        return jsonify({"error": "forbidden"}), 403
    if source["id"] == destination["id"]:
        return jsonify({"error": "source and destination must differ"}), 400
    if source["currency"] != destination["currency"]:
        return jsonify({"error": "currency mismatch"}), 400

    if source["balance_cents"] < amount:
        return jsonify({"error": "insufficient funds"}), 422

    now = int(time.time())
    db.execute(
        "UPDATE accounts SET balance_cents = balance_cents - ? WHERE id = ?",
        (amount, source["id"]),
    )
    db.execute(
        "UPDATE accounts SET balance_cents = balance_cents + ? WHERE id = ?",
        (amount, destination["id"]),
    )
    db.execute(
        "INSERT INTO ledger (account_id, amount_cents, memo, created_at) "
        "VALUES (?, ?, ?, ?)",
        (source["id"], -amount, payload.get("memo"), now),
    )
    db.execute(
        "INSERT INTO ledger (account_id, amount_cents, memo, created_at) "
        "VALUES (?, ?, ?, ?)",
        (destination["id"], amount, payload.get("memo"), now),
    )

    return jsonify({"ok": True, "amount_cents": amount}), 201


@bp.post("/<int:transfer_id>/reverse")
@require_auth
def reverse_transfer(transfer_id):
    user = current_user()
    entry = db.query_one(
        "SELECT l.id, l.account_id, l.amount_cents, a.user_id "
        "FROM ledger l JOIN accounts a ON a.id = l.account_id "
        "WHERE l.id = ?",
        (transfer_id,),
    )
    if not entry:
        return jsonify({"error": "not found"}), 404
    if entry["user_id"] != user["id"]:
        return jsonify({"error": "forbidden"}), 403

    with db.transaction() as conn:
        conn.execute(
            "UPDATE accounts SET balance_cents = balance_cents - ? WHERE id = ?",
            (entry["amount_cents"], entry["account_id"]),
        )
        conn.execute(
            "INSERT INTO ledger (account_id, amount_cents, memo, created_at) "
            "VALUES (?, ?, ?, ?)",
            (entry["account_id"], -entry["amount_cents"], "reversal", int(time.time())),
        )
    return jsonify({"ok": True})


@bp.get("/<int:account_id>/ledger")
@require_auth
def account_ledger(account_id):
    user = current_user()
    account = _load_account(account_id)
    if not account:
        return jsonify({"error": "not found"}), 404
    if account["user_id"] != user["id"]:
        return jsonify({"error": "forbidden"}), 403

    rows = db.query_all(
        "SELECT id, account_id, amount_cents, memo, created_at FROM ledger "
        "WHERE account_id = ? ORDER BY created_at DESC LIMIT 100",
        (account_id,),
    )
    return jsonify({"entries": [serializers.ledger_entry(r) for r in rows]})

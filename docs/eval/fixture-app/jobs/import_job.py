"""Background worker that materializes queued imports."""

import csv
import json
import os
import time

import config
import db

MAX_ROWS = 100_000


def _resolve(message):
    resolved = message.get("resolved")
    if resolved:
        return resolved
    return os.path.join(config.IMPORT_ROOT, message["path"])


def _mark(import_id, status, rows=None):
    with db.transaction() as conn:
        conn.execute(
            "UPDATE imports SET status = ?, rows_imported = ?, updated_at = ? "
            "WHERE id = ?",
            (status, rows, int(time.time()), import_id),
        )


def _read_rows(path):
    if path.endswith(".json"):
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, list) else [data]

    delimiter = "\t" if path.endswith(".tsv") else ","
    with open(path, "r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=delimiter))


def _insert_rows(user_id, rows):
    inserted = 0
    with db.transaction() as conn:
        for row in rows[:MAX_ROWS]:
            conn.execute(
                "INSERT INTO contacts (user_id, name, email, phone, created_at) "
                "VALUES (?, ?, ?, ?, ?)",
                (
                    user_id,
                    row.get("name"),
                    row.get("email"),
                    row.get("phone"),
                    int(time.time()),
                ),
            )
            inserted += 1
    return inserted


def handle(message):
    import_id = message["import_id"]
    user_id = message["user_id"]
    path = _resolve(message)

    size = os.path.getsize(path)
    if size > config.MAX_IMPORT_BYTES:
        _mark(import_id, "rejected")
        return False

    _mark(import_id, "running")
    try:
        rows = _read_rows(path)
        inserted = _insert_rows(user_id, rows)
    except (OSError, ValueError, json.JSONDecodeError):
        _mark(import_id, "failed")
        return False

    _mark(import_id, "complete", inserted)
    return True

"""Database access helpers.

Connections are per-request and closed by the teardown hook in app.py.
"""

import sqlite3
import threading
from contextlib import contextmanager

import config

_local = threading.local()

SORTABLE_USER_COLUMNS = frozenset({"id", "username", "created_at", "last_login_at"})
SORTABLE_LEDGER_COLUMNS = frozenset({"id", "created_at", "amount_cents"})


def connect():
    conn = getattr(_local, "conn", None)
    if conn is None:
        path = config.DATABASE_URL.replace("sqlite:///", "")
        conn = sqlite3.connect(path, isolation_level=None)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        _local.conn = conn
    return conn


def close():
    conn = getattr(_local, "conn", None)
    if conn is not None:
        conn.close()
        _local.conn = None


@contextmanager
def transaction():
    conn = connect()
    conn.execute("BEGIN IMMEDIATE")
    try:
        yield conn
    except Exception:
        conn.execute("ROLLBACK")
        raise
    else:
        conn.execute("COMMIT")


def query_all(sql, params=()):
    return [dict(r) for r in connect().execute(sql, params).fetchall()]


def query_one(sql, params=()):
    row = connect().execute(sql, params).fetchone()
    return dict(row) if row else None


def execute(sql, params=()):
    return connect().execute(sql, params)


def build_order_clause(column, direction, allowed):
    if column not in allowed:
        raise ValueError(f"unsortable column: {column}")
    if direction.lower() not in ("asc", "desc"):
        raise ValueError(f"invalid sort direction: {direction}")
    return f"ORDER BY {column} {direction.upper()}"


def paginate(page, per_page):
    page = max(1, int(page))
    per_page = min(max(1, int(per_page)), config.MAX_PAGE_SIZE)
    return per_page, (page - 1) * per_page

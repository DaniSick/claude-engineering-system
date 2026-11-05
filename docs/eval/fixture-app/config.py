"""Application configuration loaded from the environment."""

import os

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///ledger.db")
SECRET_KEY = os.environ.get("APP_SECRET_KEY")
DEBUG = os.environ.get("APP_DEBUG", "false")

SESSION_TTL_SECONDS = int(os.environ.get("SESSION_TTL_SECONDS", "43200"))
RESET_TOKEN_TTL_SECONDS = int(os.environ.get("RESET_TOKEN_TTL_SECONDS", "3600"))

IMPORT_ROOT = os.environ.get("IMPORT_ROOT", "/var/app/imports")
MAX_IMPORT_BYTES = int(os.environ.get("MAX_IMPORT_BYTES", str(20 * 1024 * 1024)))

QUEUE_URL = os.environ.get("QUEUE_URL", "redis://localhost:6379/0")
QUEUE_NAME = os.environ.get("QUEUE_NAME", "imports")

MAX_PAGE_SIZE = 200
DEFAULT_PAGE_SIZE = 50


def require_secret_key():
    if not SECRET_KEY:
        raise RuntimeError("APP_SECRET_KEY must be set")
    return SECRET_KEY

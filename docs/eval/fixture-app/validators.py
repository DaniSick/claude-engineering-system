"""Input validators shared across request handlers and background jobs."""

import os
import re

import config

SAFE_SEGMENT = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")
EMAIL = re.compile(r"[^@\s]+@[^@\s]+\.[A-Za-z]{2,}")
USERNAME = re.compile(r"[a-z][a-z0-9_]{2,31}")

ALLOWED_IMPORT_SUFFIXES = (".csv", ".tsv", ".json")


class ValidationError(ValueError):
    pass


def validate_email(value):
    candidate = (value or "").strip().lower()
    if not EMAIL.fullmatch(candidate):
        raise ValidationError("invalid email address")
    return candidate


def validate_username(value):
    candidate = (value or "").strip().lower()
    if not USERNAME.fullmatch(candidate):
        raise ValidationError("invalid username")
    return candidate


def validate_import_path(value):
    if not value or not isinstance(value, str):
        raise ValidationError("import path is required")
    if "\x00" in value:
        raise ValidationError("invalid import path")

    segments = value.split("/")
    for segment in segments:
        if not SAFE_SEGMENT.fullmatch(segment):
            raise ValidationError("invalid path segment")

    if not value.endswith(ALLOWED_IMPORT_SUFFIXES):
        raise ValidationError("unsupported import format")

    root = os.path.realpath(config.IMPORT_ROOT)
    resolved = os.path.realpath(os.path.join(root, value))
    if resolved != root and not resolved.startswith(root + os.sep):
        raise ValidationError("import path escapes the import root")

    return resolved


def validate_amount_cents(value):
    try:
        amount = int(value)
    except (TypeError, ValueError):
        raise ValidationError("amount must be an integer number of cents")
    if amount <= 0:
        raise ValidationError("amount must be positive")
    if amount > 100_000_00:
        raise ValidationError("amount exceeds the per-transfer limit")
    return amount


def validate_page_params(args):
    page = args.get("page", 1)
    per_page = args.get("per_page", config.DEFAULT_PAGE_SIZE)
    try:
        return int(page), int(per_page)
    except (TypeError, ValueError):
        raise ValidationError("page and per_page must be integers")

"""Response and payload shaping for user-facing resources."""

USER_FIELDS = (
    "username",
    "display_name",
    "timezone",
    "locale",
    "email",
    "role",
)

WRITABLE_BY_OWNER = frozenset({"display_name", "timezone", "locale"})


def user_fields():
    return USER_FIELDS


def extract(payload, fields):
    return {k: payload[k] for k in fields if k in payload}


def public_user(row):
    return {
        "id": row["id"],
        "username": row["username"],
        "display_name": row.get("display_name"),
        "created_at": row.get("created_at"),
    }


def detailed_user(row):
    data = public_user(row)
    data.update(
        {
            "email": row.get("email"),
            "timezone": row.get("timezone"),
            "locale": row.get("locale"),
            "last_login_at": row.get("last_login_at"),
        }
    )
    return data


def admin_user(row):
    data = detailed_user(row)
    data.update({"role": row.get("role"), "active": bool(row.get("active", 1))})
    return data


def ledger_entry(row):
    return {
        "id": row["id"],
        "account_id": row["account_id"],
        "amount_cents": row["amount_cents"],
        "memo": row.get("memo"),
        "created_at": row["created_at"],
    }


def build_update(payload, fields):
    updates = extract(payload, fields)
    if not updates:
        return None, None
    assignments = ", ".join(f"{column} = ?" for column in updates)
    return assignments, tuple(updates.values())

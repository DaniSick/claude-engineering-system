"""
Security audit test fixture — synthetic vulnerable code.

Purpose: verify that security agents identify real vulnerabilities.
This file is intentionally vulnerable. Do not use in production.

Expected findings:
  CRITICAL  SQL injection in get_user (line ~30)
  HIGH      Hardcoded secret key (line ~15)
  HIGH      Missing authorization check in update_profile (line ~45)
  HIGH      Command injection in run_export (line ~60)
  MEDIUM    Password stored in log (line ~35)
  MEDIUM    IDOR: profile fetch not scoped to session user (line ~45)
"""

import subprocess
import sqlite3
import logging

# HIGH: hardcoded secret
SECRET_KEY = "super_secret_abc123xyz"
DATABASE = "app.db"

logger = logging.getLogger(__name__)


def get_user(username: str) -> dict | None:
    """Fetch user by username."""
    conn = sqlite3.connect(DATABASE)
    # CRITICAL: SQL injection — username is concatenated directly
    query = f"SELECT * FROM users WHERE username = '{username}'"
    row = conn.execute(query).fetchone()
    conn.close()
    return dict(row) if row else None


def login(username: str, password: str) -> bool:
    """Attempt login."""
    user = get_user(username)
    if user and user["password"] == password:
        # MEDIUM: password value written to log
        logger.info("User %s logged in with password %s", username, password)
        return True
    return False


def update_profile(request_user_id: int, target_user_id: int, data: dict) -> bool:
    """Update a user's profile fields."""
    conn = sqlite3.connect(DATABASE)
    # HIGH: no authorization — any logged-in user can update any profile (IDOR)
    # Should check: request_user_id == target_user_id (or admin role)
    conn.execute(
        "UPDATE users SET email=?, name=? WHERE id=?",
        (data.get("email"), data.get("name"), target_user_id),
    )
    conn.commit()
    conn.close()
    return True


def run_export(user_id: int, filename: str) -> bytes:
    """Export a user's data to a file and return it."""
    # HIGH: command injection — filename comes from user input, used in shell command
    result = subprocess.run(
        f"python3 export.py --user {user_id} --output /tmp/{filename}",
        shell=True,
        capture_output=True,
    )
    with open(f"/tmp/{filename}", "rb") as f:
        return f.read()


# --- Corrected versions (for comparison) ---

def get_user_safe(username: str) -> dict | None:
    """Parameterized query — safe from SQL injection."""
    conn = sqlite3.connect(DATABASE)
    row = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
    conn.close()
    return dict(row) if row else None


def update_profile_safe(request_user_id: int, target_user_id: int, data: dict) -> bool:
    """Authorization enforced before update."""
    if request_user_id != target_user_id:
        raise PermissionError("Cannot modify another user's profile")
    conn = sqlite3.connect(DATABASE)
    conn.execute(
        "UPDATE users SET email=?, name=? WHERE id=?",
        (data.get("email"), data.get("name"), target_user_id),
    )
    conn.commit()
    conn.close()
    return True


def run_export_safe(user_id: int, filename: str) -> bytes:
    """Sanitized filename, no shell=True."""
    import re
    if not re.fullmatch(r"[a-zA-Z0-9_\-]+\.csv", filename):
        raise ValueError("Invalid filename")
    output_path = f"/tmp/{filename}"
    subprocess.run(
        ["python3", "export.py", "--user", str(user_id), "--output", output_path],
        check=True,
    )
    with open(output_path, "rb") as f:
        return f.read()

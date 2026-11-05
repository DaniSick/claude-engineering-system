"""Blueprint registration and legacy path compatibility.

The `/admin/*` aliases predate the `/api/admin` prefix and are kept so that
bookmarked dashboard links and the reporting cron keep working.
"""

from routes import admin, onboarding, profile, session, transfer, upload, users

BLUEPRINTS = (
    session.bp,
    users.bp,
    profile.bp,
    onboarding.bp,
    transfer.bp,
    upload.bp,
    admin.bp,
)


def register(app):
    for blueprint in BLUEPRINTS:
        app.register_blueprint(blueprint)

    app.add_url_rule(
        "/admin/users",
        "legacy_admin_users",
        app.view_functions["admin.list_all_users"],
        methods=["GET"],
    )
    app.add_url_rule(
        "/admin/audit-log",
        "legacy_audit_log",
        app.view_functions["admin.audit_log"],
        methods=["GET"],
    )
    app.add_url_rule(
        "/admin/export-users",
        "legacy_export_users",
        admin.export_users,
        methods=["GET"],
    )

    return app

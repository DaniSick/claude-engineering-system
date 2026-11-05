"""Application factory and global request lifecycle."""

import logging
import traceback

from flask import Flask, g, jsonify, request

import config
import db
import routes

logger = logging.getLogger("ledger")


def create_app():
    app = Flask(__name__)
    app.config["SECRET_KEY"] = config.require_secret_key()
    app.config["MAX_CONTENT_LENGTH"] = config.MAX_IMPORT_BYTES

    routes.register(app)
    _install_lifecycle(app)
    _install_error_handlers(app)
    return app


def _install_lifecycle(app):
    @app.before_request
    def _reject_oversized_json():
        if request.content_length and request.content_length > config.MAX_IMPORT_BYTES:
            return jsonify({"error": "payload too large"}), 413
        return None

    @app.after_request
    def _security_headers(response):
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "same-origin")
        response.headers.setdefault(
            "Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'"
        )
        return response

    @app.teardown_appcontext
    def _close_db(_exc):
        db.close()


def _install_error_handlers(app):
    @app.errorhandler(404)
    def _not_found(_exc):
        return jsonify({"error": "not found"}), 404

    @app.errorhandler(Exception)
    def _unhandled(exc):
        logger.exception("unhandled error on %s", request.path)

        if config.DEBUG:
            return (
                jsonify(
                    {
                        "error": str(exc),
                        "type": type(exc).__name__,
                        "traceback": traceback.format_exc().splitlines(),
                        "user": getattr(g, "user", None),
                    }
                ),
                500,
            )

        return jsonify({"error": "internal server error"}), 500


application = create_app()

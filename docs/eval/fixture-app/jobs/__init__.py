"""Background job handlers."""

from jobs import import_job

HANDLERS = {
    "imports": import_job.handle,
}


def dispatch(envelope):
    handler = HANDLERS.get(envelope.get("queue"))
    if handler is None:
        return False
    return handler(envelope["body"])

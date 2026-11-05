"""Thin publisher around the import queue."""

import json
import time

import config

_pending = []


def publish(message, queue=None):
    envelope = {
        "queue": queue or config.QUEUE_NAME,
        "published_at": int(time.time()),
        "body": message,
    }
    _pending.append(json.dumps(envelope))
    return envelope


def drain():
    items = [json.loads(raw) for raw in _pending]
    _pending.clear()
    return items


def depth():
    return len(_pending)

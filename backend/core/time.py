# backend/core/time.py
from datetime import UTC, datetime


def utc_now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)

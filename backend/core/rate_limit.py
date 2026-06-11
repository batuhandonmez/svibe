from __future__ import annotations

from collections import defaultdict, deque
from threading import Lock
from time import monotonic

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse


class SlidingWindowRateLimiter:
    """Small in-process limiter for MVP abuse protection."""

    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def allow(self, key: str, *, limit: int, window_seconds: int) -> bool:
        now = monotonic()
        cutoff = now - window_seconds
        with self._lock:
            hits = self._hits[key]
            while hits and hits[0] < cutoff:
                hits.popleft()
            if len(hits) >= limit:
                return False
            hits.append(now)
            return True


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Rate limit auth and mutating API calls by client IP."""

    def __init__(
        self,
        app,
        *,
        enabled: bool,
        auth_limit: int,
        write_limit: int,
        window_seconds: int,
    ) -> None:
        super().__init__(app)
        self.enabled = enabled
        self.auth_limit = auth_limit
        self.write_limit = write_limit
        self.window_seconds = window_seconds
        self.limiter = SlidingWindowRateLimiter()

    async def dispatch(self, request: Request, call_next):
        if not self.enabled or request.method == "OPTIONS":
            return await call_next(request)

        path = request.url.path
        bucket = None
        limit = self.write_limit
        if path in {"/auth/login", "/auth/register"}:
            bucket = "auth"
            limit = self.auth_limit
        elif request.method in {"POST", "PUT", "PATCH", "DELETE"}:
            bucket = "write"

        if bucket is None:
            return await call_next(request)

        client_host = request.client.host if request.client else "unknown"
        key = f"{bucket}:{client_host}"
        if not self.limiter.allow(
            key,
            limit=limit,
            window_seconds=self.window_seconds,
        ):
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Too many requests. Please slow down and try again."
                },
            )

        return await call_next(request)

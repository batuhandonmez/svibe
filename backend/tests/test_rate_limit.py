import core.rate_limit as rate_limit_module
from core.rate_limit import SlidingWindowRateLimiter


def test_sliding_window_rate_limiter_blocks_until_window_expires(monkeypatch):
    now = 1000.0
    monkeypatch.setattr(rate_limit_module, "monotonic", lambda: now)

    limiter = SlidingWindowRateLimiter()

    assert limiter.allow("auth:127.0.0.1", limit=2, window_seconds=10)
    assert limiter.allow("auth:127.0.0.1", limit=2, window_seconds=10)
    assert not limiter.allow("auth:127.0.0.1", limit=2, window_seconds=10)

    now = 1011.0
    assert limiter.allow("auth:127.0.0.1", limit=2, window_seconds=10)

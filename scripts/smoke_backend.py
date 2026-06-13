from __future__ import annotations

import argparse
import json
import time
from typing import Any
from urllib import error, request


def _request(
    base_url: str,
    method: str,
    path: str,
    *,
    token: str | None = None,
    payload: dict[str, Any] | None = None,
    timeout: float = 15,
) -> Any:
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = request.Request(
        f"{base_url.rstrip('/')}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with request.urlopen(req, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else None
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {path} failed: HTTP {exc.code} {body}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"{method} {path} failed: {exc.reason}") from exc


def _login(base_url: str, username: str, password: str) -> dict[str, Any]:
    return _request(
        base_url,
        "POST",
        "/auth/login",
        payload={"username": username, "password": password},
    )


def _register_smoke_user(base_url: str, password: str) -> tuple[str, dict[str, Any]]:
    username = f"smoke_{time.time_ns()}"
    session = _request(
        base_url,
        "POST",
        "/auth/register",
        payload={
            "username": username,
            "password": password,
            "display_name": "Smoke Test",
            "bio": "Temporary API smoke-check account.",
            "is_vip": True,
        },
    )
    return username, session


def main() -> int:
    parser = argparse.ArgumentParser(description="Svibe backend smoke check.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument(
        "--mode",
        choices=("demo", "register"),
        default="demo",
        help=(
            "demo logs in with seeded demo data; register creates a small "
            "temporary user through the public API."
        ),
    )
    parser.add_argument("--username", default="demo_user")
    parser.add_argument("--password", default="demo12345")
    args = parser.parse_args()

    checks: list[str] = []

    health = _request(args.base_url, "GET", "/health")
    if health.get("status") != "ok":
        raise RuntimeError(f"Unexpected health response: {health}")
    checks.append("health")

    username = args.username
    if args.mode == "register":
        username, session = _register_smoke_user(args.base_url, args.password)
        checks.append("auth/register")
    else:
        session = _login(args.base_url, args.username, args.password)
        checks.append("auth/login")

    token = session.get("access_token")
    if not token:
        raise RuntimeError("Auth did not return an access token.")

    me = _request(args.base_url, "GET", "/auth/me", token=token)
    if me.get("username") != username:
        raise RuntimeError(f"Unexpected /auth/me response: {me}")
    checks.append("auth/me")

    status = _request(args.base_url, "GET", "/users/me/status", token=token)
    if "can_upload_vibe" not in status:
        raise RuntimeError(f"Unexpected status response: {status}")
    checks.append("users/me/status")

    discover = _request(args.base_url, "GET", "/vibes/discover/next", token=token)
    if "item" not in discover:
        raise RuntimeError(f"Unexpected discover response: {discover}")
    if args.mode == "demo" and discover["item"] is None:
        raise RuntimeError(
            "Demo discover is empty. Run scripts/seed_local_demo.py first."
        )
    checks.append("vibes/discover/next")

    threads = _request(args.base_url, "GET", "/dm/threads", token=token)
    if "items" not in threads:
        raise RuntimeError(f"Unexpected DM threads response: {threads}")
    if args.mode == "demo" and not threads["items"]:
        raise RuntimeError(
            "Demo DM inbox is empty. Run scripts/seed_local_demo.py first."
        )
    checks.append("dm/threads")

    print("Smoke OK:", ", ".join(checks))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

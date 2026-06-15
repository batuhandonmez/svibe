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


def _assert_url_reachable(url: str, *, timeout: float = 15) -> None:
    req = request.Request(url, method="GET", headers={"Accept": "*/*"})
    try:
        with request.urlopen(req, timeout=timeout) as response:
            if response.status >= 400:
                raise RuntimeError(f"GET {url} failed: HTTP {response.status}")
            response.read(1)
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GET {url} failed: HTTP {exc.code} {body}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"GET {url} failed: {exc.reason}") from exc


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
    if args.mode == "demo":
        audio_url = discover["item"].get("audio_url")
        if not audio_url:
            raise RuntimeError(f"Demo discover item has no audio_url: {discover}")
        _assert_url_reachable(audio_url)
        checks.append("demo/audio_url")
    checks.append("vibes/discover/next")

    if args.mode == "demo":
        item = discover["item"]
        if not item.get("is_golden_voice"):
            raise RuntimeError(f"Demo first discover item is not Golden Voice: {item}")

        vibe_id = item["id"]
        listen = _request(
            args.base_url,
            "POST",
            f"/vibes/{vibe_id}/listen/start",
            token=token,
        )
        if listen.get("vibe_id") != vibe_id:
            raise RuntimeError(f"Unexpected listen response: {listen}")
        checks.append("vibes/listen/start")

        time.sleep(3.2)
        pending = _request(
            args.base_url,
            "POST",
            f"/vibes/{vibe_id}/swipe",
            token=token,
            payload={"direction": "like"},
        )
        if not pending.get("golden_voice_unlock_pending"):
            raise RuntimeError(f"Golden Voice did not request unlock: {pending}")
        checks.append("golden_voice/pending")

        unlocked = _request(
            args.base_url,
            "POST",
            f"/vibes/{vibe_id}/swipe",
            token=token,
            payload={"direction": "like", "golden_unlock_confirmed": True},
        )
        if not unlocked.get("golden_voice_unlocked"):
            raise RuntimeError(f"Golden Voice did not unlock: {unlocked}")
        checks.append("golden_voice/unlock")

    my_vibes = _request(args.base_url, "GET", "/vibes/mine", token=token)
    if "items" not in my_vibes:
        raise RuntimeError(f"Unexpected my vibes response: {my_vibes}")
    if args.mode == "demo" and not my_vibes["items"]:
        raise RuntimeError(
            "Demo profile archive is empty. Run scripts/seed_local_demo.py first."
        )
    checks.append("vibes/mine")

    threads = _request(args.base_url, "GET", "/dm/threads", token=token)
    if "items" not in threads:
        raise RuntimeError(f"Unexpected DM threads response: {threads}")
    if args.mode == "demo" and not threads["items"]:
        raise RuntimeError(
            "Demo DM inbox is empty. Run scripts/seed_local_demo.py first."
        )
    checks.append("dm/threads")

    if args.mode == "demo":
        thread_id = threads["items"][0]["id"]
        before = _request(
            args.base_url,
            "GET",
            f"/dm/threads/{thread_id}/messages",
            token=token,
        )
        if "items" not in before:
            raise RuntimeError(f"Unexpected DM messages response: {before}")

        text = f"Smoke hello {time.time_ns()}"
        sent = _request(
            args.base_url,
            "POST",
            f"/dm/threads/{thread_id}/messages",
            token=token,
            payload={"text": text},
        )
        if sent.get("text") != text:
            raise RuntimeError(f"Unexpected sent DM response: {sent}")

        after = _request(
            args.base_url,
            "GET",
            f"/dm/threads/{thread_id}/messages",
            token=token,
        )
        if not any(message.get("text") == text for message in after.get("items", [])):
            raise RuntimeError(f"Sent DM was not listed: {after}")
        checks.append("dm/send_text")

    print("Smoke OK:", ", ".join(checks))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

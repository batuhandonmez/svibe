# backend/tests/test_auth_and_vibes.py
from datetime import UTC, datetime, timedelta

import routers.vibes as vibes_router
from fastapi.testclient import TestClient
from sqlalchemy import text

from core.database import engine
from main import app


def _username(prefix: str) -> str:
    return f"{prefix}_{datetime.now(UTC).strftime('%Y%m%d%H%M%S%f')}"


def _register(client: TestClient, prefix: str, is_vip: bool = False) -> dict:
    response = client.post(
        "/auth/register",
        json={
            "username": _username(prefix),
            "password": "strong-pass-123",
            "is_vip": is_vip,
        },
    )
    assert response.status_code == 201
    return response.json()


def _headers(token_payload: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {token_payload['access_token']}"}


def test_auth_register_login_and_me():
    with TestClient(app) as client:
        payload = _register(client, "auth", is_vip=True)

        login = client.post(
            "/auth/login",
            json={
                "username": payload["user"]["username"],
                "password": "strong-pass-123",
            },
        )
        assert login.status_code == 200
        assert login.json()["access_token"]

        me = client.get("/auth/me", headers=_headers(payload))
        assert me.status_code == 200
        assert me.json()["username"] == payload["user"]["username"]


def test_vibe_upload_requires_token():
    with TestClient(app) as client:
        response = client.post(
            "/vibes",
            data={"duration": "3", "is_golden_voice": "false"},
            files={"audio": ("sample.m4a", b"audio", "audio/mp4")},
        )
        assert response.status_code == 401


def test_user_status_resets_expired_daily_vibe_count():
    with TestClient(app) as client:
        payload = _register(client, "quota", is_vip=True)
        with engine.begin() as connection:
            connection.execute(
                text(
                    "UPDATE users "
                    "SET daily_vibe_count = 0, daily_vibe_reset_at = :reset_at "
                    "WHERE id = :user_id"
                ),
                {
                    "reset_at": datetime.now(UTC).replace(tzinfo=None)
                    - timedelta(seconds=1),
                    "user_id": payload["user"]["id"],
                },
            )

        status_response = client.get("/users/me/status", headers=_headers(payload))
        assert status_response.status_code == 200
        status_payload = status_response.json()
        assert status_payload["daily_vibe_limit"] == 30
        assert status_payload["daily_vibe_count"] == 30
        assert status_payload["can_upload_vibe"] is True


def test_vibe_upload_feed_and_golden_voice_unlock(monkeypatch):
    deleted_audio_urls = []
    monkeypatch.setattr(
        vibes_router,
        "upload_audio_file",
        lambda user_id, audio: (
            f"https://svibe-audio-dev.s3.eu-central-1.amazonaws.com/test/{user_id}/mock.m4a"
        ),
    )
    monkeypatch.setattr(
        vibes_router,
        "create_presigned_audio_url",
        lambda audio_url: audio_url + "?signed=1",
    )
    monkeypatch.setattr(
        vibes_router,
        "delete_audio_file",
        lambda audio_url: deleted_audio_urls.append(audio_url),
    )

    with TestClient(app) as client:
        owner = _register(client, "owner", is_vip=True)
        listener = _register(client, "listener", is_vip=False)
        with engine.begin() as connection:
            connection.execute(
                text("UPDATE users SET is_muted = true WHERE id = :user_id"),
                {"user_id": listener["user"]["id"]},
            )

        upload = client.post(
            "/vibes",
            headers=_headers(owner),
            data={"duration": "3", "is_golden_voice": "true"},
            files={"audio": ("sample.m4a", b"audio", "audio/mp4")},
        )
        assert upload.status_code == 201
        vibe = upload.json()
        assert vibe["user_id"] == owner["user"]["id"]
        assert vibe["remaining_daily_vibe_count"] == 29

        owner_feed = client.get("/vibes", headers=_headers(owner))
        assert owner_feed.status_code == 200
        assert all(item["user_id"] != owner["user"]["id"] for item in owner_feed.json()["items"])

        listener_feed = client.get("/vibes", headers=_headers(listener))
        assert listener_feed.status_code == 200
        listener_items = listener_feed.json()["items"]
        feed_vibe = next(item for item in listener_items if item["id"] == vibe["id"])
        assert feed_vibe["username"] == owner["user"]["username"]
        assert feed_vibe["profile_picture_url"] is None
        assert feed_vibe["listen_started_at"] is None
        assert feed_vibe["can_swipe_at"] is None
        assert feed_vibe["can_swipe_now"] is False

        own_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe-right",
            headers=_headers(owner),
        )
        assert own_swipe.status_code == 400

        no_listen_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe-right",
            headers=_headers(listener),
        )
        assert no_listen_swipe.status_code == 403

        listen = client.post(
            f"/vibes/{vibe['id']}/listen/start",
            headers=_headers(listener),
        )
        assert listen.status_code == 200
        assert listen.json()["can_swipe_after_seconds"] == 3

        listener_feed_after_listen = client.get("/vibes", headers=_headers(listener))
        assert listener_feed_after_listen.status_code == 200
        feed_vibe_after_listen = next(
            item
            for item in listener_feed_after_listen.json()["items"]
            if item["id"] == vibe["id"]
        )
        assert feed_vibe_after_listen["listen_started_at"] is not None
        assert feed_vibe_after_listen["can_swipe_at"] is not None
        assert feed_vibe_after_listen["can_swipe_now"] is False

        too_soon_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe-right",
            headers=_headers(listener),
        )
        assert too_soon_swipe.status_code == 403

        with engine.begin() as connection:
            connection.execute(
                text(
                    "UPDATE vibe_listens "
                    "SET started_at = :started_at "
                    "WHERE user_id = :user_id AND vibe_id = :vibe_id"
                ),
                {
                    "started_at": datetime.now(UTC).replace(tzinfo=None)
                    - timedelta(seconds=4),
                    "user_id": listener["user"]["id"],
                    "vibe_id": vibe["id"],
                },
            )

        listener_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe-right",
            headers=_headers(listener),
        )
        assert listener_swipe.status_code == 200
        assert listener_swipe.json()["golden_voice_unlocked"] is True

        listener_delete = client.delete(
            f"/vibes/{vibe['id']}",
            headers=_headers(listener),
        )
        assert listener_delete.status_code == 403

        owner_delete = client.delete(
            f"/vibes/{vibe['id']}",
            headers=_headers(owner),
        )
        assert owner_delete.status_code == 200
        assert owner_delete.json()["deleted"] is True
        assert deleted_audio_urls == [
            "https://svibe-audio-dev.s3.eu-central-1.amazonaws.com/test/"
            f"{owner['user']['id']}/mock.m4a"
        ]

        deleted_feed = client.get("/vibes", headers=_headers(listener))
        assert deleted_feed.status_code == 200
        assert all(item["id"] != vibe["id"] for item in deleted_feed.json()["items"])

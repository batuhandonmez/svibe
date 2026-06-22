# backend/tests/test_auth_and_vibes.py
from datetime import UTC, datetime, timedelta
from uuid import UUID

import pytest
import routers.dm as dm_router
import routers.users as users_router
import routers.vibes as vibes_router
from fastapi.testclient import TestClient
from sqlalchemy import select, text, update

from core.config import settings
from core.database import Base, engine
from core.database import SessionLocal
from core.migrations import apply_lightweight_migrations
from main import app
from models.user import User
from models.vibe import Vibe
from models.vibe_listen import VibeListen
from models.vibe_swipe import VibeSwipe
from services.demo_seed import seed_demo_data


@pytest.fixture(autouse=True)
def _clean_database():
    Base.metadata.create_all(bind=engine)
    apply_lightweight_migrations(engine)
    with engine.begin() as connection:
        for table in (
            "dm_messages",
            "dm_threads",
            "vibe_swipes",
            "vibe_listens",
            "follows",
            "vibes",
            "users",
        ):
            connection.execute(text(f"DELETE FROM {table}"))


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


def test_demo_seed_rewrites_stale_demo_audio_urls_and_duplicates(monkeypatch):
    monkeypatch.setattr(settings, "LOCAL_MEDIA_BASE_URL", "http://old.local:8000")
    with SessionLocal() as db:
        seed_demo_data(db)
        demo_user = db.scalar(select(User).where(User.username == "demo_listener"))
        nova = db.scalar(select(User).where(User.username == "nova_signal"))
        stale_vibe = Vibe(
            user_id=nova.id,
            audio_url="http://192.168.1.102:8000/media/demo/nova-golden-voice.wav",
            duration=10,
            is_golden_voice=True,
        )
        db.add(stale_vibe)
        db.flush()
        db.add(VibeListen(user_id=demo_user.id, vibe_id=stale_vibe.id))
        db.add(VibeSwipe(user_id=demo_user.id, vibe_id=stale_vibe.id, direction="like"))
        db.commit()

    monkeypatch.setattr(settings, "LOCAL_MEDIA_BASE_URL", "http://127.0.0.1:8000")
    with SessionLocal() as db:
        seed_demo_data(db)

    with SessionLocal() as db:
        vibes = db.scalars(
            select(Vibe).where(Vibe.audio_url.like("%/nova-golden-voice.wav"))
        ).all()
        assert len(vibes) == 1
        assert vibes[0].audio_url == (
            "http://127.0.0.1:8000/media/demo/nova-golden-voice.wav"
        )


def test_demo_listener_sees_golden_then_latest_creator_vibe(monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    monkeypatch.setattr(vibes_router, "create_presigned_audio_url", lambda value: value)
    with SessionLocal() as db:
        seed_demo_data(db)
        listener = db.scalar(select(User).where(User.username == "demo_listener"))
        creator = db.scalar(select(User).where(User.username == "demo_creator"))
        assert listener.is_muted is True
        assert creator.is_muted is False

    with TestClient(app) as client:
        login = client.post(
            "/auth/login",
            json={"username": "demo_listener", "password": "demo12345"},
        )
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        first = client.get("/vibes/discover/next", headers=headers)
        assert first.json()["item"]["is_golden_voice"] is True

        with SessionLocal() as db:
            listener = db.scalar(select(User).where(User.username == "demo_listener"))
            creator = db.scalar(select(User).where(User.username == "demo_creator"))
            listener.is_muted = False
            creator_vibe = Vibe(
                user_id=creator.id,
                audio_url="local://demo/creator-live.wav",
                duration=8,
                expires_at=datetime.now(UTC).replace(tzinfo=None) + timedelta(days=1),
            )
            db.add_all([listener, creator_vibe])
            db.commit()
            creator_vibe_id = str(creator_vibe.id)

        next_vibe = client.get("/vibes/discover/next", headers=headers)
        assert next_vibe.json()["item"]["id"] == creator_vibe_id


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
                update(User)
                .where(User.id == UUID(payload["user"]["id"]))
                .values(
                    daily_vibe_count=0,
                    daily_vibe_reset_at=datetime.now(UTC).replace(tzinfo=None)
                    - timedelta(seconds=1),
                ),
            )

        status_response = client.get("/users/me/status", headers=_headers(payload))
        assert status_response.status_code == 200
        status_payload = status_response.json()
        assert status_payload["daily_vibe_limit"] == 30
        assert status_payload["daily_vibe_count"] == 30
        assert status_payload["can_upload_vibe"] is True


def test_profile_photo_upload_updates_user(monkeypatch):
    uploaded = {}

    def fake_upload_profile_image(user_id, photo):
        uploaded["user_id"] = str(user_id)
        uploaded["filename"] = photo.filename
        uploaded["content_type"] = photo.content_type
        return f"https://cdn.example.test/profiles/{user_id}/avatar.png"

    monkeypatch.setattr(users_router, "upload_profile_image", fake_upload_profile_image)

    with TestClient(app) as client:
        payload = _register(client, "photo", is_vip=True)

        response = client.post(
            "/users/me/photo",
            headers=_headers(payload),
            files={"photo": ("avatar.png", b"fake-png", "image/png")},
        )

        assert response.status_code == 200
        assert response.json()["profile_picture_url"].endswith("/avatar.png")
        assert uploaded == {
            "user_id": payload["user"]["id"],
            "filename": "avatar.png",
            "content_type": "image/png",
        }

        me = client.get("/auth/me", headers=_headers(payload))
        assert me.status_code == 200
        assert me.json()["profile_picture_url"].endswith("/avatar.png")


def test_user_create_ignores_profile_photo_url():
    with TestClient(app) as client:
        response = client.post(
            "/users",
            json={
                "username": _username("legacy_photo"),
                "display_name": "Legacy Photo",
                "profile_picture_url": "https://example.test/avatar.png",
                "is_vip": True,
            },
        )

        assert response.status_code == 201
        assert response.json()["profile_picture_url"] is None


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
    monkeypatch.setattr(vibes_router.random, "random", lambda: 0.0)
    monkeypatch.setattr(vibes_router, "MIN_LISTEN_SECONDS_BEFORE_SWIPE", 999)

    with TestClient(app) as client:
        owner = _register(client, "owner", is_vip=True)
        listener = _register(client, "listener", is_vip=False)
        with engine.begin() as connection:
            connection.execute(
                update(User)
                .where(User.id == UUID(listener["user"]["id"]))
                .values(is_muted=True),
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
        assert vibe["is_golden_voice"] is True
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

        second_upload = client.post(
            "/vibes",
            headers=_headers(owner),
            data={"duration": "4"},
            files={"audio": ("second.m4a", b"second audio", "audio/mp4")},
        )
        assert second_upload.status_code == 201

        discover = client.get(
            "/vibes/discover/next",
            headers=_headers(listener),
            params={"exclude_id": second_upload.json()["id"]},
        )
        assert discover.status_code == 200
        assert discover.json()["item"]["id"] == vibe["id"]

        own_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe",
            headers=_headers(owner),
            json={"direction": "like"},
        )
        assert own_swipe.status_code == 400

        no_listen_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe",
            headers=_headers(listener),
            json={"direction": "like"},
        )
        assert no_listen_swipe.status_code == 403

        listen = client.post(
            f"/vibes/{vibe['id']}/listen/start",
            headers=_headers(listener),
        )
        assert listen.status_code == 200
        assert listen.json()["can_swipe_after_seconds"] == 999

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
            f"/vibes/{vibe['id']}/swipe",
            headers=_headers(listener),
            json={"direction": "like"},
        )
        assert too_soon_swipe.status_code == 403

        with engine.begin() as connection:
            connection.execute(
                update(VibeListen)
                .where(
                    VibeListen.user_id == UUID(listener["user"]["id"]),
                    VibeListen.vibe_id == UUID(vibe["id"]),
                )
                .values(
                    started_at=datetime.now(UTC).replace(tzinfo=None)
                    - timedelta(seconds=1000),
                ),
            )

        pending_unlock = client.post(
            f"/vibes/{vibe['id']}/swipe",
            headers=_headers(listener),
            json={"direction": "like"},
        )
        assert pending_unlock.status_code == 200
        assert pending_unlock.json()["golden_voice_unlock_pending"] is True

        listener_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe",
            headers=_headers(listener),
            json={"direction": "like", "golden_unlock_confirmed": True},
        )
        assert listener_swipe.status_code == 200
        assert listener_swipe.json()["golden_voice_unlocked"] is True

        repeated_swipe = client.post(
            f"/vibes/{vibe['id']}/swipe",
            headers=_headers(listener),
            json={"direction": "dislike"},
        )
        assert repeated_swipe.status_code == 409

        skipped_discover = client.get("/vibes/discover/next", headers=_headers(listener))
        assert skipped_discover.status_code == 200
        assert skipped_discover.json()["item"]["id"] == second_upload.json()["id"]

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


def test_private_profile_follow_and_dm_settings(monkeypatch):
    monkeypatch.setattr(
        vibes_router,
        "upload_audio_file",
        lambda user_id, audio: (
            f"https://svibe-audio-dev.s3.eu-central-1.amazonaws.com/test/{user_id}/private.m4a"
        ),
    )
    monkeypatch.setattr(vibes_router.random, "random", lambda: 0.99)
    monkeypatch.setattr(
        dm_router,
        "upload_dm_audio_file",
        lambda user_id, audio: (
            f"https://svibe-audio-dev.s3.eu-central-1.amazonaws.com/dm/{user_id}/voice.m4a"
        ),
    )
    monkeypatch.setattr(dm_router, "create_presigned_audio_url", lambda url: url)

    with TestClient(app) as client:
        owner = _register(client, "private_owner", is_vip=True)
        listener = _register(client, "private_listener", is_vip=True)

        update = client.patch(
            "/users/me",
            headers=_headers(owner),
            json={
                "display_name": "Private Signal",
                "bio": "low-noise profile",
                "is_private": True,
                "message_privacy": "followers",
            },
        )
        assert update.status_code == 200
        assert update.json()["is_private"] is True
        assert update.json()["message_privacy"] == "followers"

        upload = client.post(
            "/vibes",
            headers=_headers(owner),
            data={"duration": "4"},
            files={"audio": ("sample.m4a", b"audio", "audio/mp4")},
        )
        assert upload.status_code == 201
        assert upload.json()["is_golden_voice"] is False

        hidden = client.get("/vibes/discover/next", headers=_headers(listener))
        assert hidden.status_code == 200
        assert hidden.json()["item"] is None

        request = client.post(
            f"/users/{owner['user']['id']}/follow",
            headers=_headers(listener),
        )
        assert request.status_code == 200
        assert request.json()["status"] == "pending"

        accept = client.post(
            f"/users/{listener['user']['id']}/follow/accept",
            headers=_headers(owner),
        )
        assert accept.status_code == 200
        assert accept.json()["status"] == "accepted"

        thread = client.post(
            "/dm/threads",
            headers=_headers(listener),
            json={"user_id": owner["user"]["id"]},
        )
        assert thread.status_code == 201
        assert thread.json()["peer"]["username"] == owner["user"]["username"]

        message = client.post(
            f"/dm/threads/{thread.json()['id']}/messages",
            headers=_headers(listener),
            json={"text": "heard your signal"},
        )
        assert message.status_code == 201
        assert message.json()["text"] == "heard your signal"

        audio_message = client.post(
            f"/dm/threads/{thread.json()['id']}/messages/audio",
            headers=_headers(listener),
            data={"duration": "5"},
            files={"audio": ("voice.m4a", b"audio", "audio/mp4")},
        )
        assert audio_message.status_code == 201
        assert audio_message.json()["text"] is None
        assert audio_message.json()["audio_url"].endswith("/voice.m4a")

        inbox = client.get("/dm/threads", headers=_headers(owner))
        assert inbox.status_code == 200
        assert inbox.json()["items"][0]["last_message"]["audio_url"].endswith(
            "/voice.m4a"
        )


def test_dm_privacy_blocks_non_followers():
    with TestClient(app) as client:
        owner = _register(client, "dm_owner", is_vip=True)
        stranger = _register(client, "dm_stranger", is_vip=True)

        update = client.patch(
            "/users/me",
            headers=_headers(owner),
            json={"message_privacy": "followers"},
        )
        assert update.status_code == 200

        blocked = client.post(
            "/dm/threads",
            headers=_headers(stranger),
            json={"user_id": owner["user"]["id"]},
        )
        assert blocked.status_code == 403

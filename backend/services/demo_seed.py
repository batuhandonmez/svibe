from __future__ import annotations

from datetime import timedelta

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from core.config import settings
from core.security import hash_password
from core.time import utc_now
from models.dm_message import DmMessage
from models.dm_thread import DmThread
from models.user import User
from models.vibe import Vibe
from models.vibe_listen import VibeListen
from models.vibe_swipe import VibeSwipe


DEMO_PASSWORD = "demo12345"


DEMO_USERS = [
    {
        "username": "demo_user",
        "display_name": "Demo Listener",
        "bio": "Presentation-ready account for exploring Svibe.",
        "is_muted": True,
        "daily_vibe_count": 0,
        "is_vip": False,
    },
    {
        "username": "nova_signal",
        "display_name": "Nova Signal",
        "bio": "Late-night voice notes, rare signals and quiet thoughts.",
        "is_muted": False,
        "daily_vibe_count": 30,
        "is_vip": True,
    },
    {
        "username": "elara_v",
        "display_name": "Elara Vance",
        "bio": "Ambient walks, city echoes and small voice postcards.",
        "is_muted": False,
        "daily_vibe_count": 30,
        "is_vip": True,
    },
    {
        "username": "mira_city",
        "display_name": "Mira City",
        "bio": "Capturing tiny street sounds before they disappear.",
        "is_muted": False,
        "daily_vibe_count": 30,
        "is_vip": True,
    },
    {
        "username": "atlas_notes",
        "display_name": "Atlas Notes",
        "bio": "Short spoken notes from trains, cafes and quiet corners.",
        "is_muted": False,
        "daily_vibe_count": 30,
        "is_vip": True,
    },
]


DEMO_VIBES = [
    {
        "username": "nova_signal",
        "file": "nova-golden-voice.wav",
        "duration": 10,
        "is_golden_voice": True,
        "swipe_right_count": 42,
    },
    {
        "username": "elara_v",
        "file": "echo-morning-note.wav",
        "duration": 18,
        "is_golden_voice": False,
        "swipe_right_count": 12,
    },
    {
        "username": "mira_city",
        "file": "mira-city-walk.wav",
        "duration": 16,
        "is_golden_voice": False,
        "swipe_right_count": 9,
    },
    {
        "username": "atlas_notes",
        "file": "atlas-short-thought.wav",
        "duration": 14,
        "is_golden_voice": False,
        "swipe_right_count": 7,
    },
]


DEMO_OWN_VIBES = [
    {
        "username": "demo_user",
        "file": "demo-user-archive.wav",
        "duration": 14,
        "is_golden_voice": False,
        "swipe_right_count": 5,
    },
]


DEMO_MESSAGES = [
    ("elara_v", "I found a quiet alley with a perfect echo today."),
    ("demo_user", "That sounds exactly like the kind of signal Svibe needs."),
    ("elara_v", None),
    ("demo_user", "Send it over. I want to hear the texture."),
]


def _demo_audio_url(filename: str) -> str:
    return f"{settings.LOCAL_MEDIA_BASE_URL.rstrip('/')}/media/demo/{filename}"


def _get_or_create_user(db: Session, payload: dict[str, object]) -> User:
    user = db.scalar(select(User).where(User.username == payload["username"]))
    if user is None:
        user = User(username=payload["username"], password_hash=hash_password(DEMO_PASSWORD))
        db.add(user)
        db.flush()

    user.display_name = payload["display_name"]
    user.bio = payload["bio"]
    user.is_private = False
    user.message_privacy = "everyone"
    user.is_muted = bool(payload["is_muted"])
    user.daily_vibe_count = int(payload["daily_vibe_count"])
    user.is_vip = bool(payload["is_vip"])
    if not user.password_hash:
        user.password_hash = hash_password(DEMO_PASSWORD)
    return user


def _thread_pair(user_a: User, user_b: User) -> tuple:
    ordered = sorted([user_a.id, user_b.id])
    return ordered[0], ordered[1]


def seed_demo_data(db: Session) -> None:
    """Create stable local demo data for presentations and manual MVP testing."""
    users = {payload["username"]: _get_or_create_user(db, payload) for payload in DEMO_USERS}
    demo_user = users["demo_user"]

    db.flush()

    db.execute(delete(VibeSwipe).where(VibeSwipe.user_id == demo_user.id))
    db.execute(delete(VibeListen).where(VibeListen.user_id == demo_user.id))

    expires_at = utc_now() + timedelta(days=7)
    for payload in [*DEMO_VIBES, *DEMO_OWN_VIBES]:
        owner = users[payload["username"]]
        audio_url = _demo_audio_url(payload["file"])
        vibe = db.scalar(select(Vibe).where(Vibe.audio_url == audio_url))
        if vibe is None:
            vibe = Vibe(user_id=owner.id, audio_url=audio_url, duration=payload["duration"])
            db.add(vibe)
        vibe.user_id = owner.id
        vibe.duration = payload["duration"]
        vibe.is_golden_voice = payload["is_golden_voice"]
        vibe.swipe_right_count = payload["swipe_right_count"]
        vibe.expires_at = expires_at

    peer = users["elara_v"]
    low_id, high_id = _thread_pair(demo_user, peer)
    thread = db.scalar(
        select(DmThread).where(
            DmThread.user_low_id == low_id,
            DmThread.user_high_id == high_id,
        )
    )
    if thread is None:
        thread = DmThread(user_low_id=low_id, user_high_id=high_id)
        db.add(thread)
        db.flush()
    else:
        db.execute(delete(DmMessage).where(DmMessage.thread_id == thread.id))

    for sender_username, text in DEMO_MESSAGES:
        sender = users[sender_username]
        db.add(
            DmMessage(
                thread_id=thread.id,
                sender_id=sender.id,
                text=text,
                audio_url=_demo_audio_url("demo-user-archive.wav") if text is None else None,
            )
        )
    thread.updated_at = utc_now()
    db.commit()

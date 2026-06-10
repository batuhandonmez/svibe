from __future__ import annotations

import io
import math
import os
import sys
import wave
from datetime import timedelta
from pathlib import Path

import boto3
from sqlalchemy import delete, select

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
sys.path.insert(0, str(BACKEND))
os.chdir(BACKEND)

from core.config import settings  # noqa: E402
from core.database import SessionLocal  # noqa: E402
from core.security import hash_password  # noqa: E402
from core.time import utc_now  # noqa: E402
from models.dm_message import DmMessage  # noqa: E402
from models.dm_thread import DmThread  # noqa: E402
from models.user import User  # noqa: E402
from models.vibe import Vibe  # noqa: E402
from models.vibe_listen import VibeListen  # noqa: E402
from models.vibe_swipe import VibeSwipe  # noqa: E402


DEMO_PASSWORD = "demo12345"
DEMO_USERS = [
    ("demo_user", "Demo User", "Showing Svibe's voice-first flow.", False, "everyone"),
    ("mira_wave", "Mira Wave", "Short city notes and night walks.", False, "everyone"),
    ("atlas_signal", "Atlas", "Tiny thoughts in short waves.", False, "everyone"),
    ("nova_signal", "Nova Signal", "Golden Voice hunter.", False, "followers"),
    ("echo_deniz", "Echo Deniz", "Morning notes and street sounds.", False, "everyone"),
]
DEMO_VIBES = [
    ("demo_user", 14, 330.0, 42, False, "demo-own-intro.wav"),
    ("mira_wave", 12, 440.0, 84, False, "mira-city-walk.wav"),
    ("atlas_signal", 15, 523.25, 118, False, "atlas-short-thought.wav"),
    ("nova_signal", 10, 659.25, 231, True, "nova-golden-voice.wav"),
    ("echo_deniz", 18, 392.0, 47, False, "echo-morning-note.wav"),
]


def make_wav(freq: float, seconds: int) -> bytes:
    sample_rate = 22050
    frames = int(sample_rate * seconds)
    out = io.BytesIO()
    with wave.open(out, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        for i in range(frames):
            fade_in = i / (sample_rate * 0.16)
            fade_out = (frames - i) / (sample_rate * 0.22)
            envelope = max(0.0, min(1.0, fade_in, fade_out))
            tone = math.sin(2 * math.pi * freq * i / sample_rate)
            wobble = math.sin(2 * math.pi * (freq * 0.5) * i / sample_rate) * 0.24
            value = int(18000 * envelope * (tone + wobble))
            wav.writeframesraw(value.to_bytes(2, byteorder="little", signed=True))
    return out.getvalue()


def s3_url(key: str) -> str:
    return (
        f"https://{settings.AWS_S3_BUCKET_NAME}.s3."
        f"{settings.AWS_REGION}.amazonaws.com/{key}"
    )


def thread_pair(a, b):
    return tuple(sorted([a, b], key=str))


def upsert_user(db, username, display_name, bio, is_private, message_privacy):
    user = db.scalar(select(User).where(User.username == username))
    if user is None:
        user = User(username=username)
        db.add(user)
        db.flush()
    user.display_name = display_name
    user.bio = bio
    user.password_hash = hash_password(DEMO_PASSWORD)
    user.is_muted = False
    user.is_vip = True
    user.daily_vibe_count = 30
    user.is_private = is_private
    user.message_privacy = message_privacy
    return user


def main() -> None:
    if not all(
        [
            settings.AWS_ACCESS_KEY_ID,
            settings.AWS_SECRET_ACCESS_KEY,
            settings.AWS_S3_BUCKET_NAME,
        ]
    ):
        raise SystemExit("Missing S3 settings in backend/.env")

    s3 = boto3.client(
        "s3",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )
    db = SessionLocal()
    try:
        users = {
            username: upsert_user(db, username, display, bio, private, privacy)
            for username, display, bio, private, privacy in DEMO_USERS
        }
        db.flush()

        demo = users["demo_user"]
        db.execute(delete(VibeSwipe).where(VibeSwipe.user_id == demo.id))
        db.execute(delete(VibeListen).where(VibeListen.user_id == demo.id))

        for username, duration, freq, likes, golden, filename in DEMO_VIBES:
            owner = users[username]
            key = f"{settings.AWS_S3_AUDIO_PREFIX.strip('/')}/demo/{filename}"
            s3.upload_fileobj(
                io.BytesIO(make_wav(freq, duration)),
                settings.AWS_S3_BUCKET_NAME,
                key,
                ExtraArgs={"ContentType": "audio/wav"},
            )
            url = s3_url(key)
            vibe = db.scalar(
                select(Vibe).where(Vibe.user_id == owner.id, Vibe.audio_url == url)
            )
            if vibe is None:
                vibe = Vibe(user_id=owner.id, audio_url=url)
                db.add(vibe)
            vibe.duration = duration
            vibe.swipe_right_count = likes
            vibe.is_golden_voice = golden
            vibe.expires_at = utc_now() + timedelta(days=7)

        friend = users["mira_wave"]
        low, high = thread_pair(demo.id, friend.id)
        thread = db.scalar(
            select(DmThread).where(
                DmThread.user_low_id == low,
                DmThread.user_high_id == high,
            )
        )
        if thread is None:
            thread = DmThread(user_low_id=low, user_high_id=high)
            db.add(thread)
            db.flush()
        db.execute(delete(DmMessage).where(DmMessage.thread_id == thread.id))
        db.add_all(
            [
                DmMessage(
                    thread_id=thread.id,
                    sender_id=friend.id,
                    text="The one-card feed feels much clearer now.",
                ),
                DmMessage(
                    thread_id=thread.id,
                    sender_id=demo.id,
                    text="Right is like, left is pass. Cast sits in the center.",
                ),
                DmMessage(
                    thread_id=thread.id,
                    sender_id=friend.id,
                    text="Show me the Golden Voice shake screen next.",
                ),
            ]
        )
        thread.updated_at = utc_now()
        db.commit()
        print("Seeded demo_user/demo12345 with demo vibes and DM.")
    finally:
        db.close()


if __name__ == "__main__":
    main()

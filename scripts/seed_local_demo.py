from __future__ import annotations

import argparse
import io
import math
import os
import shutil
import sys
import wave
from datetime import timedelta
from pathlib import Path

from sqlalchemy import delete, or_, select

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
sys.path.insert(0, str(BACKEND))
os.chdir(BACKEND)

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
    ("demo_listener", "Demo Listener", "Presentation listener account.", False, "everyone"),
    ("demo_creator", "Demo Creator", "Presentation creator account.", False, "everyone"),
    ("mira_wave", "Mira Wave", "Night walks, small city notes.", False, "everyone"),
    ("atlas_signal", "Atlas", "Short thoughts in clean audio.", False, "everyone"),
    ("nova_signal", "Nova Signal", "Rare Golden Voice energy.", False, "followers"),
    ("echo_deniz", "Echo Deniz", "Morning sounds and street fragments.", False, "everyone"),
]
DEMO_VIBES = [
    ("mira_wave", 12, 440.0, 84, False, "mira-city-walk.wav"),
    ("atlas_signal", 15, 523.25, 118, False, "atlas-short-thought.wav"),
    ("nova_signal", 10, 659.25, 231, True, "nova-golden-voice.wav"),
    ("echo_deniz", 18, 392.0, 47, False, "echo-morning-note.wav"),
]
DEMO_VIEWER_VIBES = [
    (14, 330.0, 42, False, "demo-user-archive.wav"),
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
            fade_in = i / (sample_rate * 0.12)
            fade_out = (frames - i) / (sample_rate * 0.2)
            envelope = max(0.0, min(1.0, fade_in, fade_out))
            tone = math.sin(2 * math.pi * freq * i / sample_rate)
            wobble = math.sin(2 * math.pi * (freq * 0.5) * i / sample_rate) * 0.18
            value = int(16000 * envelope * (tone + wobble))
            wav.writeframesraw(value.to_bytes(2, byteorder="little", signed=True))
    return out.getvalue()


def prepare_audio(path: Path, freq: float, seconds: int) -> None:
    source = ROOT / "scripts" / "demo_audio" / path.name
    if source.exists():
        shutil.copyfile(source, path)
    else:
        path.write_bytes(make_wav(freq, seconds))


def wav_duration(path: Path, fallback: int) -> int:
    try:
        with wave.open(str(path), "rb") as wav:
            return min(30, max(1, math.ceil(wav.getnframes() / wav.getframerate())))
    except (wave.Error, OSError, ZeroDivisionError):
        return fallback


def upsert_demo_user(db, username, display_name, bio, is_private, message_privacy):
    user = db.scalar(select(User).where(User.username == username))
    if user is None:
        user = User(username=username)
        db.add(user)
        db.flush()
    user.display_name = display_name
    user.bio = bio
    user.password_hash = hash_password(DEMO_PASSWORD)
    user.is_muted = username == "demo_listener"
    user.is_vip = username != "demo_listener"
    user.daily_vibe_count = 0 if username == "demo_listener" else 30
    user.is_private = is_private
    user.message_privacy = message_privacy
    return user


def thread_pair(a, b):
    return tuple(sorted([a, b], key=str))


def add_thread(db, viewer, peer, messages):
    low, high = thread_pair(viewer.id, peer.id)
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

    if db.scalar(select(DmMessage).where(DmMessage.thread_id == thread.id)) is None:
        for sender, text in messages:
            db.add(
                DmMessage(
                    thread_id=thread.id,
                    sender_id=sender.id,
                    text=text,
                )
            )
    thread.updated_at = utc_now()


def latest_user(db) -> User:
    user = db.scalar(select(User).order_by(User.created_at.desc()).limit(1))
    if user is None:
        raise SystemExit("No users found. Create an account first.")
    return user


def viewer_user(db, username: str | None) -> User:
    if not username:
        return latest_user(db)

    user = db.scalar(select(User).where(User.username == username))
    if user is not None:
        return user

    user = User(
        username=username,
        display_name=username.replace("_", " ").title(),
        bio="Local demo account.",
        password_hash=hash_password(DEMO_PASSWORD),
        is_muted=username == "demo_listener",
        is_vip=username != "demo_listener",
        daily_vibe_count=0 if username == "demo_listener" else 30,
        is_private=False,
        message_privacy="everyone",
    )
    db.add(user)
    db.flush()
    return user


def upsert_demo_vibe(db, user, audio_url, duration, likes, golden):
    matching_vibes = db.scalars(
        select(Vibe).where(Vibe.audio_url.like(f"%{audio_url.rsplit('/', 1)[-1]}"))
    ).all()
    vibe = matching_vibes[0] if matching_vibes else None
    if vibe is None:
        vibe = Vibe(user_id=user.id, audio_url=audio_url)
        db.add(vibe)
    duplicate_ids = [duplicate.id for duplicate in matching_vibes[1:]]
    if duplicate_ids:
        db.execute(delete(VibeListen).where(VibeListen.vibe_id.in_(duplicate_ids)))
        db.execute(delete(VibeSwipe).where(VibeSwipe.vibe_id.in_(duplicate_ids)))
        for duplicate in matching_vibes[1:]:
            db.delete(duplicate)
    vibe.user_id = user.id
    vibe.audio_url = audio_url
    vibe.duration = duration
    vibe.swipe_right_count = likes
    vibe.is_golden_voice = golden
    vibe.expires_at = utc_now() + timedelta(days=7)
    db.flush()
    return vibe


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed local demo vibes and DMs.")
    parser.add_argument("--username", default="demo_listener")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()

    media_dir = BACKEND / "local_media" / "demo"
    media_dir.mkdir(parents=True, exist_ok=True)

    db = SessionLocal()
    try:
        viewer = viewer_user(db, args.username)
        users = {
            username: upsert_demo_user(db, username, display, bio, private, privacy)
            for username, display, bio, private, privacy in DEMO_USERS
        }
        db.flush()

        demo_vibe_ids = []
        for username, duration, freq, likes, golden, filename in DEMO_VIBES:
            path = media_dir / filename
            prepare_audio(path, freq, duration)
            duration = wav_duration(path, duration)
            audio_url = f"{args.base_url.rstrip('/')}/media/demo/{filename}"
            vibe = upsert_demo_vibe(
                db,
                users[username],
                audio_url,
                duration,
                likes,
                golden,
            )
            demo_vibe_ids.append(vibe.id)

        for duration, freq, likes, golden, filename in DEMO_VIEWER_VIBES:
            path = media_dir / filename
            prepare_audio(path, freq, duration)
            duration = wav_duration(path, duration)
            audio_url = f"{args.base_url.rstrip('/')}/media/demo/{filename}"
            upsert_demo_vibe(db, viewer, audio_url, duration, likes, golden)

        if demo_vibe_ids:
            db.execute(
                delete(VibeListen).where(
                    VibeListen.user_id == viewer.id,
                    VibeListen.vibe_id.in_(demo_vibe_ids),
                )
            )
            db.execute(
                delete(VibeSwipe).where(
                    VibeSwipe.user_id == viewer.id,
                    VibeSwipe.vibe_id.in_(demo_vibe_ids),
                )
            )

        old_thread_ids = db.scalars(
            select(DmThread.id).where(
                or_(
                    DmThread.user_low_id == viewer.id,
                    DmThread.user_high_id == viewer.id,
                )
            )
        ).all()
        if old_thread_ids:
            db.execute(delete(DmMessage).where(DmMessage.thread_id.in_(old_thread_ids)))
            db.execute(delete(DmThread).where(DmThread.id.in_(old_thread_ids)))

        add_thread(
            db,
            viewer,
            users["demo_creator"],
            [
                (users["demo_creator"], "I just recorded a new vibe. Check your feed."),
                (viewer, "Got it. I can hear it clearly."),
            ],
        )
        db.commit()
        print(f"Seeded local demo for {viewer.username}.")
    finally:
        db.close()


if __name__ == "__main__":
    main()

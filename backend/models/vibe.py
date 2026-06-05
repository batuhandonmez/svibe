# backend/models/vibe.py
import uuid
from datetime import datetime, timedelta

from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base
from core.time import utc_now


def _default_expires_at() -> datetime:
    """Vibe olusturulduktan 24 saat sonra sona erer."""
    return utc_now() + timedelta(hours=24)


class Vibe(Base):
    """Ses kaydi (Vibe) tablosu."""

    __tablename__ = "vibes"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), nullable=False
    )
    audio_url: Mapped[str] = mapped_column(
        String(500), nullable=False
    )
    duration: Mapped[int] = mapped_column(
        Integer, nullable=False, comment="Maksimum 30 saniye"
    )
    swipe_right_count: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False
    )
    is_golden_voice: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime, default=_default_expires_at, nullable=False
    )

# backend/models/user.py
import uuid
from datetime import datetime, timedelta

from sqlalchemy import String, Boolean, Integer, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base
from core.time import utc_now


class User(Base):
    """Kullanici tablosu."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True, default=uuid.uuid4
    )
    username: Mapped[str] = mapped_column(
        String(50), unique=True, nullable=False
    )
    display_name: Mapped[str | None] = mapped_column(
        String(80), nullable=True
    )
    bio: Mapped[str | None] = mapped_column(
        String(240), nullable=True
    )
    profile_picture_url: Mapped[str | None] = mapped_column(
        String(500), nullable=True
    )
    is_private: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    message_privacy: Mapped[str] = mapped_column(
        String(20), default="everyone", nullable=False
    )
    password_hash: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )
    is_muted: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )
    daily_vibe_count: Mapped[int] = mapped_column(
        Integer, default=3, nullable=False
    )
    daily_vibe_reset_at: Mapped[datetime | None] = mapped_column(
        DateTime, default=lambda: utc_now() + timedelta(days=1), nullable=True
    )
    is_vip: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, nullable=False
    )

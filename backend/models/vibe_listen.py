# backend/models/vibe_listen.py
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base
from core.time import utc_now


class VibeListen(Base):
    """Tracks when a user starts listening to a vibe."""

    __tablename__ = "vibe_listens"
    __table_args__ = (
        UniqueConstraint("user_id", "vibe_id", name="uq_vibe_listens_user_vibe"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), nullable=False
    )
    vibe_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vibes.id"), nullable=False
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, nullable=False
    )

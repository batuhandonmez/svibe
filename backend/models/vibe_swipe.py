# backend/models/vibe_swipe.py
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base
from core.time import utc_now


class VibeSwipe(Base):
    """Stores a user's final like/dislike decision for a vibe."""

    __tablename__ = "vibe_swipes"
    __table_args__ = (
        UniqueConstraint("user_id", "vibe_id", name="uq_vibe_swipes_user_vibe"),
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
    direction: Mapped[str] = mapped_column(String(10), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, nullable=False
    )

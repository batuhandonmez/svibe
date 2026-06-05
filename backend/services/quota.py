from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from core.config import settings
from core.time import utc_now
from models.user import User


def daily_vibe_limit_for_user(user: User) -> int:
    if user.is_vip:
        return settings.VIP_DAILY_VIBE_COUNT
    return settings.DEFAULT_DAILY_VIBE_COUNT


def next_daily_vibe_reset_at(now: datetime | None = None) -> datetime:
    return (now or utc_now()) + timedelta(days=1)


def reset_daily_vibe_count_if_needed(user: User, db: Session) -> User:
    now = utc_now()
    if user.daily_vibe_reset_at is not None and user.daily_vibe_reset_at > now:
        return user

    user.daily_vibe_count = daily_vibe_limit_for_user(user)
    user.daily_vibe_reset_at = next_daily_vibe_reset_at(now)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

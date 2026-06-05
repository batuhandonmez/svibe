# backend/routers/users.py
import random
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.config import settings
from core.database import get_db
from core.security import get_current_user
from models.user import User
from schemas.users import UserCreate, UserCreateResponse, UserRead, UserStatusResponse
from services.quota import daily_vibe_limit_for_user

router = APIRouter(prefix="/users", tags=["Users"])


def _onboarding_state(is_vip: bool) -> tuple[bool, int, str, str]:
    if is_vip:
        return (
            False,
            settings.VIP_DAILY_VIBE_COUNT,
            "vip",
            "VIP user starts with speaking rights.",
        )

    lucky = random.randint(1, 100) <= settings.LUCKY_UNMUTED_PERCENT
    if lucky:
        return (
            False,
            settings.DEFAULT_DAILY_VIBE_COUNT,
            "lucky_unmuted",
            "Lucky user starts with speaking rights.",
        )

    return (
        True,
        settings.DEFAULT_DAILY_VIBE_COUNT,
        "muted_majority",
        "User starts muted and must listen first.",
    )


@router.post("", response_model=UserCreateResponse, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    is_muted, daily_count, scenario, message = _onboarding_state(payload.is_vip)
    user = User(
        username=payload.username,
        profile_picture_url=payload.profile_picture_url,
        is_vip=payload.is_vip,
        is_muted=is_muted,
        daily_vibe_count=daily_count,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already exists.",
        ) from exc

    db.refresh(user)
    return UserCreateResponse(
        **UserRead.model_validate(user).model_dump(),
        onboarding_scenario=scenario,
        message=message,
    )


@router.get("/{user_id}", response_model=UserRead)
def get_user(user_id: UUID, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    return user


@router.get("/me/status", response_model=UserStatusResponse)
def get_my_status(current_user: User = Depends(get_current_user)):
    return UserStatusResponse(
        is_muted=current_user.is_muted,
        daily_vibe_count=current_user.daily_vibe_count,
        daily_vibe_limit=daily_vibe_limit_for_user(current_user),
        daily_vibe_reset_at=current_user.daily_vibe_reset_at,
        can_upload_vibe=not current_user.is_muted and current_user.daily_vibe_count > 0,
    )

# backend/routers/users.py
import random
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.config import settings
from core.database import get_db
from core.security import get_current_user
from models.follow import Follow
from models.user import User
from models.vibe import Vibe
from schemas.users import (
    FollowResponse,
    ProfilePhotoResponse,
    UserCreate,
    UserCreateResponse,
    UserRead,
    UserStatusResponse,
    UserUpdate,
)
from services.quota import daily_vibe_limit_for_user
from services.s3_storage import upload_profile_image

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
        display_name=payload.display_name,
        bio=payload.bio,
        profile_picture_url=payload.profile_picture_url,
        is_private=payload.is_private,
        message_privacy=payload.message_privacy,
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
def get_my_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    followers_count = db.scalar(
        select(func.count()).select_from(Follow).where(
            Follow.following_id == current_user.id,
            Follow.status == "accepted",
        )
    )
    following_count = db.scalar(
        select(func.count()).select_from(Follow).where(
            Follow.follower_id == current_user.id,
            Follow.status == "accepted",
        )
    )
    vibes_count = db.scalar(
        select(func.count()).select_from(Vibe).where(Vibe.user_id == current_user.id)
    )
    return UserStatusResponse(
        is_muted=current_user.is_muted,
        daily_vibe_count=current_user.daily_vibe_count,
        daily_vibe_limit=daily_vibe_limit_for_user(current_user),
        daily_vibe_reset_at=current_user.daily_vibe_reset_at,
        can_upload_vibe=not current_user.is_muted and current_user.daily_vibe_count > 0,
        is_private=current_user.is_private,
        message_privacy=current_user.message_privacy,
        followers_count=followers_count or 0,
        following_count=following_count or 0,
        vibes_count=vibes_count or 0,
    )


@router.patch("/me", response_model=UserRead)
def update_me(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.display_name is not None:
        current_user.display_name = payload.display_name
    if payload.bio is not None:
        current_user.bio = payload.bio
    if payload.is_private is not None:
        current_user.is_private = payload.is_private
    if payload.message_privacy is not None:
        current_user.message_privacy = payload.message_privacy

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/me/photo", response_model=ProfilePhotoResponse)
def upload_my_profile_photo(
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile_picture_url = upload_profile_image(current_user.id, photo)
    current_user.profile_picture_url = profile_picture_url
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return ProfilePhotoResponse(profile_picture_url=profile_picture_url)


@router.post("/{user_id}/follow", response_model=FollowResponse)
def follow_user(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    if target.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Users cannot follow themselves.",
        )

    relationship = db.scalar(
        select(Follow).where(
            Follow.follower_id == current_user.id,
            Follow.following_id == target.id,
        )
    )
    desired_status = "pending" if target.is_private else "accepted"
    if relationship is None:
        relationship = Follow(
            follower_id=current_user.id,
            following_id=target.id,
            status=desired_status,
        )
    else:
        relationship.status = desired_status

    db.add(relationship)
    db.commit()
    db.refresh(relationship)
    return FollowResponse(following_id=target.id, status=relationship.status)


@router.post("/{user_id}/follow/accept", response_model=FollowResponse)
def accept_follow_request(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    relationship = db.scalar(
        select(Follow).where(
            Follow.follower_id == user_id,
            Follow.following_id == current_user.id,
        )
    )
    if relationship is None or relationship.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pending follow request not found.",
        )

    relationship.status = "accepted"
    db.add(relationship)
    db.commit()
    db.refresh(relationship)
    return FollowResponse(following_id=current_user.id, status=relationship.status)

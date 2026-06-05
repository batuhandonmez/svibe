# backend/routers/vibes.py
from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from core.time import utc_now
from models.user import User
from models.vibe import Vibe
from models.vibe_listen import VibeListen
from schemas.vibes import (
    DeleteVibeResponse,
    FeedResponse,
    ListenStartResponse,
    SwipeResponse,
    VibeFeedItem,
    VibeRead,
    VibeUploadResponse,
)
from services.s3_storage import (
    create_presigned_audio_url,
    delete_audio_file,
    upload_audio_file,
)

router = APIRouter(prefix="/vibes", tags=["Vibes"])
MIN_LISTEN_SECONDS_BEFORE_SWIPE = 3


def _to_vibe_read(vibe: Vibe) -> VibeRead:
    payload = VibeRead.model_validate(vibe).model_dump()
    payload["audio_url"] = create_presigned_audio_url(vibe.audio_url)
    return VibeRead(**payload)


def _to_feed_item(vibe: Vibe, owner: User, listen: VibeListen | None) -> VibeFeedItem:
    payload = _to_vibe_read(vibe).model_dump()
    can_swipe_at = None
    can_swipe_now = False
    if listen is not None:
        can_swipe_at = listen.started_at + timedelta(
            seconds=MIN_LISTEN_SECONDS_BEFORE_SWIPE
        )
        can_swipe_now = utc_now() >= can_swipe_at

    return VibeFeedItem(
        **payload,
        username=owner.username,
        profile_picture_url=owner.profile_picture_url,
        listen_started_at=listen.started_at if listen is not None else None,
        can_swipe_at=can_swipe_at,
        can_swipe_now=can_swipe_now,
    )


@router.post("", response_model=VibeUploadResponse, status_code=status.HTTP_201_CREATED)
def upload_vibe(
    duration: int = Form(...),
    is_golden_voice: bool = Form(False),
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.is_muted:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Muted users cannot upload vibes yet.",
        )
    if current_user.daily_vibe_count <= 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Daily vibe limit reached.",
        )
    if duration < 1 or duration > 30:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vibe duration must be between 1 and 30 seconds.",
        )

    audio_url = upload_audio_file(current_user.id, audio)
    vibe = Vibe(
        user_id=current_user.id,
        audio_url=audio_url,
        duration=duration,
        is_golden_voice=is_golden_voice,
    )
    current_user.daily_vibe_count -= 1

    db.add(vibe)
    db.add(current_user)
    try:
        db.commit()
    except SQLAlchemyError as exc:
        db.rollback()
        delete_audio_file(audio_url)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not save vibe after audio upload.",
        ) from exc
    db.refresh(vibe)
    db.refresh(current_user)

    return VibeUploadResponse(
        **_to_vibe_read(vibe).model_dump(),
        remaining_daily_vibe_count=current_user.daily_vibe_count,
    )


@router.get("", response_model=FeedResponse)
def list_vibes(
    limit: int = 20,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if limit < 1 or limit > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Limit must be between 1 and 100.",
        )
    if offset < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Offset must be 0 or greater.",
        )

    statement = (
        select(Vibe, User)
        .join(User, User.id == Vibe.user_id)
        .where(Vibe.expires_at > utc_now())
        .where(Vibe.user_id != current_user.id)
        .order_by(Vibe.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    rows = db.execute(statement).all()
    vibe_ids = [vibe.id for vibe, _ in rows]
    listens_by_vibe_id: dict[UUID, VibeListen] = {}
    if vibe_ids:
        listens = db.scalars(
            select(VibeListen).where(
                VibeListen.user_id == current_user.id,
                VibeListen.vibe_id.in_(vibe_ids),
            )
        ).all()
        listens_by_vibe_id = {listen.vibe_id: listen for listen in listens}

    return FeedResponse(
        items=[
            _to_feed_item(vibe, owner, listens_by_vibe_id.get(vibe.id))
            for vibe, owner in rows
        ],
        limit=limit,
        offset=offset,
    )


@router.delete("/{vibe_id}", response_model=DeleteVibeResponse)
def delete_vibe(
    vibe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    vibe = db.get(Vibe, vibe_id)
    if vibe is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vibe not found.",
        )
    if vibe.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Users can delete only their own vibes.",
        )

    audio_url = vibe.audio_url
    db.execute(delete(VibeListen).where(VibeListen.vibe_id == vibe.id))
    db.delete(vibe)
    db.commit()
    delete_audio_file(audio_url)

    return DeleteVibeResponse(vibe_id=vibe_id, deleted=True)


@router.post("/{vibe_id}/listen/start", response_model=ListenStartResponse)
def start_listening(
    vibe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    vibe = db.get(Vibe, vibe_id)
    if vibe is None or vibe.expires_at <= utc_now():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active vibe not found.",
        )
    if vibe.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Users cannot listen-start their own vibes.",
        )

    existing = db.scalar(
        select(VibeListen).where(
            VibeListen.user_id == current_user.id,
            VibeListen.vibe_id == vibe.id,
        )
    )
    if existing is not None:
        return ListenStartResponse(
            vibe_id=vibe.id,
            started_at=existing.started_at,
            can_swipe_after_seconds=MIN_LISTEN_SECONDS_BEFORE_SWIPE,
        )

    listen = VibeListen(user_id=current_user.id, vibe_id=vibe.id)
    db.add(listen)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        listen = db.scalar(
            select(VibeListen).where(
                VibeListen.user_id == current_user.id,
                VibeListen.vibe_id == vibe.id,
            )
        )
        if listen is None:
            raise

    db.refresh(listen)
    return ListenStartResponse(
        vibe_id=vibe.id,
        started_at=listen.started_at,
        can_swipe_after_seconds=MIN_LISTEN_SECONDS_BEFORE_SWIPE,
    )


@router.post("/{vibe_id}/swipe-right", response_model=SwipeResponse)
def swipe_right(
    vibe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    vibe = db.get(Vibe, vibe_id)
    if vibe is None or vibe.expires_at <= utc_now():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active vibe not found.",
        )
    if vibe.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Users cannot swipe right on their own vibes.",
        )

    listen = db.scalar(
        select(VibeListen).where(
            VibeListen.user_id == current_user.id,
            VibeListen.vibe_id == vibe.id,
        )
    )
    if listen is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Start listening before swiping.",
        )

    listened_seconds = (utc_now() - listen.started_at).total_seconds()
    if listened_seconds < MIN_LISTEN_SECONDS_BEFORE_SWIPE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Listen for at least 3 seconds before swiping.",
        )

    vibe.swipe_right_count += 1
    unlocked = False
    message = None

    if current_user.is_muted and vibe.is_golden_voice:
        current_user.is_muted = False
        unlocked = True
        message = "Golden Voice unlocked. Speaking rights granted."

    db.add(vibe)
    db.add(current_user)
    db.commit()
    db.refresh(vibe)

    return SwipeResponse(
        vibe_id=vibe.id,
        swipe_right_count=vibe.swipe_right_count,
        golden_voice_unlocked=unlocked,
        message=message,
    )

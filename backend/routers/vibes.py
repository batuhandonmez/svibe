# backend/routers/vibes.py
import random
from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from core.config import settings
from core.database import get_db
from core.security import get_current_user
from core.time import utc_now
from models.follow import Follow
from models.user import User
from models.vibe import Vibe
from models.vibe_listen import VibeListen
from models.vibe_swipe import VibeSwipe
from schemas.vibes import (
    DeleteVibeResponse,
    DiscoverResponse,
    FeedResponse,
    ListenStartResponse,
    SwipeRequest,
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
GOLDEN_VOICE_RATE = 0.03


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
        display_name=owner.display_name,
        profile_picture_url=owner.profile_picture_url,
        listen_started_at=listen.started_at if listen is not None else None,
        can_swipe_at=can_swipe_at,
        can_swipe_now=can_swipe_now,
    )


def _can_view_owner(owner: User, viewer: User, db: Session) -> bool:
    if owner.id == viewer.id or not owner.is_private:
        return True
    relationship = db.scalar(
        select(Follow).where(
            Follow.follower_id == viewer.id,
            Follow.following_id == owner.id,
            Follow.status == "accepted",
        )
    )
    return relationship is not None


def _ensure_can_interact(vibe: Vibe, current_user: User, db: Session) -> User:
    owner = db.get(User, vibe.user_id)
    if owner is None or not _can_view_owner(owner, current_user, db):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active vibe not found.",
        )
    return owner


@router.post("", response_model=VibeUploadResponse, status_code=status.HTTP_201_CREATED)
def upload_vibe(
    duration: int = Form(...),
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
        is_golden_voice=random.random() < GOLDEN_VOICE_RATE,
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


@router.get("/discover/next", response_model=DiscoverResponse)
def discover_next_vibe(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    exclude_id: UUID | None = None,
):
    swiped_ids = select(VibeSwipe.vibe_id).where(VibeSwipe.user_id == current_user.id)
    statement = (
        select(Vibe, User)
        .join(User, User.id == Vibe.user_id)
        .where(Vibe.expires_at > utc_now())
        .where(Vibe.user_id != current_user.id)
        .where(User.is_private.is_(False))
        .where(Vibe.id.not_in(swiped_ids))
        .order_by(Vibe.created_at.desc())
        .limit(100)
    )
    if exclude_id is not None:
        statement = statement.where(Vibe.id != exclude_id)
    rows = db.execute(statement).all()
    if not rows:
        return DiscoverResponse(item=None)

    demo_should_stage_unlock = (
        settings.ENVIRONMENT.lower() in {"development", "dev"}
        and current_user.username == "demo_listener"
        and current_user.is_muted
    )
    if demo_should_stage_unlock:
        swipe_count = db.scalar(
            select(func.count()).select_from(VibeSwipe).where(
                VibeSwipe.user_id == current_user.id
            )
        )
        if swipe_count == 0 and exclude_id is None:
            normal_rows = [(vibe, owner) for vibe, owner in rows if not vibe.is_golden_voice]
            choices = normal_rows or rows
        else:
            golden_rows = [(vibe, owner) for vibe, owner in rows if vibe.is_golden_voice]
            choices = golden_rows or rows
        vibe, owner = max(choices, key=lambda row: row[0].swipe_right_count)
    else:
        creator_rows = [
            (vibe, owner) for vibe, owner in rows if owner.username == "demo_creator"
        ]
        if current_user.username == "demo_listener" and creator_rows:
            vibe, owner = max(creator_rows, key=lambda row: row[0].created_at)
        else:
            weights = [max(1, vibe.swipe_right_count + 1) for vibe, _ in rows]
            vibe, owner = random.choices(rows, weights=weights, k=1)[0]
    listen = db.scalar(
        select(VibeListen).where(
            VibeListen.user_id == current_user.id,
            VibeListen.vibe_id == vibe.id,
        )
    )
    return DiscoverResponse(item=_to_feed_item(vibe, owner, listen))


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
        .where(User.is_private.is_(False))
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


@router.get("/mine", response_model=FeedResponse)
def list_my_vibes(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    vibes = db.scalars(
        select(Vibe)
        .where(Vibe.user_id == current_user.id)
        .order_by(Vibe.created_at.desc())
    ).all()
    return FeedResponse(
        items=[_to_feed_item(vibe, current_user, None) for vibe in vibes],
        limit=len(vibes),
        offset=0,
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
    db.execute(delete(VibeSwipe).where(VibeSwipe.vibe_id == vibe.id))
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
    _ensure_can_interact(vibe, current_user, db)

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
    return swipe_vibe(
        vibe_id,
        SwipeRequest(direction="like", golden_unlock_confirmed=True),
        current_user,
        db,
    )


@router.post("/{vibe_id}/swipe", response_model=SwipeResponse)
def swipe_vibe(
    vibe_id: UUID,
    payload: SwipeRequest,
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
            detail="Users cannot swipe on their own vibes.",
        )
    _ensure_can_interact(vibe, current_user, db)

    existing_swipe = db.scalar(
        select(VibeSwipe).where(
            VibeSwipe.user_id == current_user.id,
            VibeSwipe.vibe_id == vibe.id,
        )
    )
    if existing_swipe is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This vibe has already been swiped.",
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

    if (
        payload.direction == "like"
        and current_user.is_muted
        and vibe.is_golden_voice
        and not payload.golden_unlock_confirmed
    ):
        return SwipeResponse(
            vibe_id=vibe.id,
            direction=payload.direction,
            swipe_right_count=vibe.swipe_right_count,
            golden_voice_unlock_pending=True,
            message="Golden Voice found. Shake your vibe to unlock speaking rights.",
        )

    if payload.direction == "like":
        vibe.swipe_right_count += 1

    swipe = VibeSwipe(
        user_id=current_user.id,
        vibe_id=vibe.id,
        direction=payload.direction,
    )
    unlocked = False
    message = None

    if (
        payload.direction == "like"
        and current_user.is_muted
        and vibe.is_golden_voice
        and payload.golden_unlock_confirmed
    ):
        current_user.is_muted = False
        unlocked = True
        message = "Shake your vibe complete. Speaking rights granted."

    db.add(swipe)
    db.add(vibe)
    db.add(current_user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This vibe has already been swiped.",
        ) from exc
    db.refresh(vibe)

    return SwipeResponse(
        vibe_id=vibe.id,
        direction=payload.direction,
        swipe_right_count=vibe.swipe_right_count,
        golden_voice_unlocked=unlocked,
        message=message,
    )

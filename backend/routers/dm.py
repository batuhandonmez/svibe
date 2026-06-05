# backend/routers/dm.py
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from core.time import utc_now
from models.dm_message import DmMessage
from models.dm_thread import DmThread
from models.follow import Follow
from models.user import User
from schemas.dm import (
    DmMessageCreate,
    DmMessageListResponse,
    DmMessageRead,
    DmPeer,
    DmThreadCreate,
    DmThreadListResponse,
    DmThreadRead,
)

router = APIRouter(prefix="/dm", tags=["DM"])


def _thread_pair(user_a: UUID, user_b: UUID) -> tuple[UUID, UUID]:
    ordered = sorted([user_a, user_b], key=str)
    return ordered[0], ordered[1]


def _is_participant(thread: DmThread, user_id: UUID) -> bool:
    return user_id in {thread.user_low_id, thread.user_high_id}


def _peer_for_thread(thread: DmThread, current_user: User, db: Session) -> User:
    peer_id = (
        thread.user_high_id
        if thread.user_low_id == current_user.id
        else thread.user_low_id
    )
    peer = db.get(User, peer_id)
    if peer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="DM peer not found.",
        )
    return peer


def _to_message_read(message: DmMessage) -> DmMessageRead:
    return DmMessageRead(
        id=message.id,
        thread_id=message.thread_id,
        sender_id=message.sender_id,
        text=message.text,
        audio_url=message.audio_url,
        created_at=message.created_at,
    )


def _to_thread_read(
    thread: DmThread,
    current_user: User,
    db: Session,
) -> DmThreadRead:
    peer = _peer_for_thread(thread, current_user, db)
    last_message = db.scalar(
        select(DmMessage)
        .where(DmMessage.thread_id == thread.id)
        .order_by(DmMessage.created_at.desc())
        .limit(1)
    )
    return DmThreadRead(
        id=thread.id,
        peer=DmPeer(
            id=peer.id,
            username=peer.username,
            display_name=peer.display_name,
            profile_picture_url=peer.profile_picture_url,
            message_privacy=peer.message_privacy,
        ),
        created_at=thread.created_at,
        updated_at=thread.updated_at,
        last_message=_to_message_read(last_message) if last_message else None,
    )


def _can_start_dm(sender: User, receiver: User, db: Session) -> bool:
    if receiver.message_privacy == "everyone":
        return True
    if receiver.message_privacy == "off":
        return False
    return (
        db.scalar(
            select(Follow).where(
                Follow.follower_id == sender.id,
                Follow.following_id == receiver.id,
                Follow.status == "accepted",
            )
        )
        is not None
    )


@router.get("/threads", response_model=DmThreadListResponse)
def list_threads(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    threads = db.scalars(
        select(DmThread)
        .where(
            or_(
                DmThread.user_low_id == current_user.id,
                DmThread.user_high_id == current_user.id,
            )
        )
        .order_by(DmThread.updated_at.desc())
    ).all()
    return DmThreadListResponse(
        items=[_to_thread_read(thread, current_user, db) for thread in threads]
    )


@router.post("/threads", response_model=DmThreadRead, status_code=status.HTTP_201_CREATED)
def create_thread(
    payload: DmThreadCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Users cannot DM themselves.",
        )
    peer = db.get(User, payload.user_id)
    if peer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    if not _can_start_dm(current_user, peer, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This user does not accept DMs from you.",
        )

    user_low_id, user_high_id = _thread_pair(current_user.id, peer.id)
    thread = db.scalar(
        select(DmThread).where(
            DmThread.user_low_id == user_low_id,
            DmThread.user_high_id == user_high_id,
        )
    )
    if thread is None:
        thread = DmThread(user_low_id=user_low_id, user_high_id=user_high_id)
        db.add(thread)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            thread = db.scalar(
                select(DmThread).where(
                    DmThread.user_low_id == user_low_id,
                    DmThread.user_high_id == user_high_id,
                )
            )
            if thread is None:
                raise
        db.refresh(thread)

    return _to_thread_read(thread, current_user, db)


@router.get("/threads/{thread_id}/messages", response_model=DmMessageListResponse)
def list_messages(
    thread_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    thread = db.get(DmThread, thread_id)
    if thread is None or not _is_participant(thread, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="DM thread not found.",
        )
    messages = db.scalars(
        select(DmMessage)
        .where(DmMessage.thread_id == thread.id)
        .order_by(DmMessage.created_at.asc())
    ).all()
    return DmMessageListResponse(items=[_to_message_read(message) for message in messages])


@router.post(
    "/threads/{thread_id}/messages",
    response_model=DmMessageRead,
    status_code=status.HTTP_201_CREATED,
)
def send_message(
    thread_id: UUID,
    payload: DmMessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    thread = db.get(DmThread, thread_id)
    if thread is None or not _is_participant(thread, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="DM thread not found.",
        )
    peer = _peer_for_thread(thread, current_user, db)
    if not _can_start_dm(current_user, peer, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This user does not accept DMs from you.",
        )

    message = DmMessage(
        thread_id=thread.id,
        sender_id=current_user.id,
        text=payload.text,
    )
    thread.updated_at = utc_now()
    db.add(message)
    db.add(thread)
    db.commit()
    db.refresh(message)
    return _to_message_read(message)

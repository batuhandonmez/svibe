# backend/schemas/dm.py
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class DmThreadCreate(BaseModel):
    user_id: UUID


class DmMessageCreate(BaseModel):
    text: str = Field(min_length=1, max_length=1000)


class DmPeer(BaseModel):
    id: UUID
    username: str
    display_name: str | None = None
    profile_picture_url: str | None = None
    message_privacy: str


class DmMessageRead(BaseModel):
    id: UUID
    thread_id: UUID
    sender_id: UUID
    text: str | None = None
    audio_url: str | None = None
    created_at: datetime


class DmThreadRead(BaseModel):
    id: UUID
    peer: DmPeer
    created_at: datetime
    updated_at: datetime
    last_message: DmMessageRead | None = None


class DmThreadListResponse(BaseModel):
    items: list[DmThreadRead]


class DmMessageListResponse(BaseModel):
    items: list[DmMessageRead]

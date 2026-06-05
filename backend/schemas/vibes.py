# backend/schemas/vibes.py
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class VibeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    audio_url: str
    duration: int
    swipe_right_count: int
    is_golden_voice: bool
    created_at: datetime
    expires_at: datetime


class VibeFeedItem(VibeRead):
    username: str
    display_name: str | None = None
    profile_picture_url: str | None
    listen_started_at: datetime | None = None
    can_swipe_at: datetime | None = None
    can_swipe_now: bool = False


class DiscoverResponse(BaseModel):
    item: VibeFeedItem | None


class FeedResponse(BaseModel):
    items: list[VibeFeedItem]
    limit: int
    offset: int


class SwipeRequest(BaseModel):
    direction: str = Field(pattern="^(like|dislike)$")
    golden_unlock_confirmed: bool = False


class SwipeResponse(BaseModel):
    vibe_id: UUID
    direction: str
    swipe_right_count: int
    golden_voice_unlocked: bool = False
    golden_voice_unlock_pending: bool = False
    message: str | None = None


class DeleteVibeResponse(BaseModel):
    vibe_id: UUID
    deleted: bool


class ListenStartResponse(BaseModel):
    vibe_id: UUID
    started_at: datetime
    can_swipe_after_seconds: int


class VibeUploadResponse(VibeRead):
    remaining_daily_vibe_count: int = Field(ge=0)

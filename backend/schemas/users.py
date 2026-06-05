# backend/schemas/users.py
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    profile_picture_url: str | None = Field(default=None, max_length=500)
    is_vip: bool = False


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    profile_picture_url: str | None
    is_muted: bool
    daily_vibe_count: int
    daily_vibe_reset_at: datetime | None
    is_vip: bool
    created_at: datetime


class UserCreateResponse(UserRead):
    onboarding_scenario: str
    message: str


class UserStatusResponse(BaseModel):
    is_muted: bool
    daily_vibe_count: int
    daily_vibe_limit: int
    daily_vibe_reset_at: datetime | None
    can_upload_vibe: bool

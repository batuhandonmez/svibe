# backend/schemas/users.py
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    display_name: str | None = Field(default=None, max_length=80)
    bio: str | None = Field(default=None, max_length=240)
    is_private: bool = False
    message_privacy: str = Field(default="everyone", pattern="^(everyone|followers|off)$")
    is_vip: bool = False


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    display_name: str | None
    bio: str | None
    profile_picture_url: str | None
    is_private: bool
    message_privacy: str
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
    is_private: bool
    message_privacy: str
    followers_count: int = 0
    following_count: int = 0
    vibes_count: int = 0


class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=80)
    bio: str | None = Field(default=None, max_length=240)
    is_private: bool | None = None
    message_privacy: str | None = Field(default=None, pattern="^(everyone|followers|off)$")


class FollowResponse(BaseModel):
    following_id: UUID
    status: str


class ProfilePhotoResponse(BaseModel):
    profile_picture_url: str

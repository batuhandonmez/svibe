# backend/schemas/auth.py
from pydantic import BaseModel, Field

from schemas.users import UserRead


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=80)
    bio: str | None = Field(default=None, max_length=240)
    is_private: bool = False
    message_privacy: str = Field(default="everyone", pattern="^(everyone|followers|off)$")
    is_vip: bool = False


class LoginRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead

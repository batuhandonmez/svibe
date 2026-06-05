# backend/schemas/auth.py
from pydantic import BaseModel, Field

from schemas.users import UserRead


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=128)
    profile_picture_url: str | None = Field(default=None, max_length=500)
    is_vip: bool = False


class LoginRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead

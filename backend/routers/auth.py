# backend/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)
from models.user import User
from routers.users import _onboarding_state
from schemas.auth import LoginRequest, RegisterRequest, TokenResponse
from schemas.users import UserRead

router = APIRouter(prefix="/auth", tags=["Auth"])


def _token_response(user: User) -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token(user.id),
        user=UserRead.model_validate(user),
    )


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    is_muted, daily_count, _, _ = _onboarding_state(payload.is_vip)
    user = User(
        username=payload.username,
        profile_picture_url=payload.profile_picture_url,
        password_hash=hash_password(payload.password),
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
    return _token_response(user)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.username == payload.username))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
        )
    return _token_response(user)


@router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    return current_user

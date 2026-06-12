import pytest
from pydantic import ValidationError

from core.config import Settings


def test_production_rejects_default_jwt_secret():
    with pytest.raises(ValidationError, match="JWT_SECRET_KEY must be changed"):
        Settings(
            DATABASE_URL="postgresql://postgres:password@example.com/postgres",
            ENVIRONMENT="production",
            JWT_SECRET_KEY="svibe-dev-change-me",
        )


def test_production_requires_long_jwt_secret():
    with pytest.raises(ValidationError, match="at least 32 characters"):
        Settings(
            DATABASE_URL="postgresql://postgres:password@example.com/postgres",
            ENVIRONMENT="production",
            JWT_SECRET_KEY="short-secret",
        )


def test_local_cors_regex_is_disabled_in_production():
    settings = Settings(
        DATABASE_URL="postgresql://postgres:password@example.com/postgres",
        ENVIRONMENT="production",
        JWT_SECRET_KEY="a-production-secret-that-is-long-enough",
    )

    assert settings.cors_local_origin_regex is None


def test_local_cors_regex_is_enabled_in_development():
    settings = Settings(
        DATABASE_URL="postgresql://postgres:password@example.com/postgres",
        ENVIRONMENT="development",
    )

    assert settings.cors_local_origin_regex is not None

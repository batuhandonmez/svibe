# backend/core/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from `.env`."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    DATABASE_URL: str
    CORS_ALLOW_ORIGINS: str = (
        "http://localhost:3000,"
        "http://127.0.0.1:3000,"
        "http://localhost:5173,"
        "http://127.0.0.1:5173,"
        "http://localhost:8090,"
        "http://127.0.0.1:8090,"
        "http://localhost:8093,"
        "http://127.0.0.1:8093"
    )
    AWS_ACCESS_KEY_ID: str | None = None
    AWS_SECRET_ACCESS_KEY: str | None = None
    AWS_REGION: str = "eu-central-1"
    AWS_S3_BUCKET_NAME: str | None = None
    AWS_S3_AUDIO_PREFIX: str = "vibes"
    MAX_AUDIO_FILE_SIZE_MB: int = 20
    DEFAULT_DAILY_VIBE_COUNT: int = 3
    VIP_DAILY_VIBE_COUNT: int = 30
    LUCKY_UNMUTED_PERCENT: int = 10
    JWT_SECRET_KEY: str = "svibe-dev-change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_WINDOW_SECONDS: int = 60
    AUTH_RATE_LIMIT_PER_WINDOW: int = 30
    WRITE_RATE_LIMIT_PER_WINDOW: int = 120

    @property
    def cors_allow_origins(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.CORS_ALLOW_ORIGINS.split(",")
            if origin.strip()
        ]


settings = Settings()

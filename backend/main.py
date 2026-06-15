# backend/main.py
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from core.config import settings
from core.database import Base, SessionLocal, engine
from core.migrations import apply_lightweight_migrations
from core.rate_limit import RateLimitMiddleware
from models import DmMessage, DmThread, Follow, User, Vibe, VibeListen, VibeSwipe  # noqa: F401
from routers.auth import router as auth_router
from routers.dm import router as dm_router
from routers.health import router as health_router
from routers.users import router as users_router
from routers.vibes import router as vibes_router
from services.demo_seed import seed_demo_data


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    apply_lightweight_migrations(engine)
    if settings.SEED_DEMO_DATA and settings.ENVIRONMENT.lower() in {"development", "dev"}:
        db = SessionLocal()
        try:
            seed_demo_data(db)
            print("Demo data is ready: demo_user / demo12345")
        finally:
            db.close()
    print("Tables are ready: users, vibes, vibe_listens, vibe_swipes, follows, dm")
    yield


app = FastAPI(
    title="Svibe API",
    description="Audio-first social network backend service.",
    version="0.1.0",
    lifespan=lifespan,
)

if settings.cors_allow_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allow_origins,
        allow_origin_regex=settings.cors_local_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.add_middleware(
    RateLimitMiddleware,
    enabled=settings.RATE_LIMIT_ENABLED,
    auth_limit=settings.AUTH_RATE_LIMIT_PER_WINDOW,
    write_limit=settings.WRITE_RATE_LIMIT_PER_WINDOW,
    window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
)

local_media_dir = Path(__file__).resolve().parent / "local_media"
local_media_dir.mkdir(exist_ok=True)
app.mount("/media", StaticFiles(directory=local_media_dir), name="media")

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(vibes_router)
app.include_router(dm_router)

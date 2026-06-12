# backend/core/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from core.config import settings

database_url = settings.DATABASE_URL
connect_args = {}
if database_url.startswith("postgresql://"):
    database_url = database_url.replace("postgresql://", "postgresql+psycopg://", 1)
    connect_args["prepare_threshold"] = None

engine = create_engine(
    database_url,
    pool_pre_ping=True,
    connect_args=connect_args,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Tüm modellerin miras alacağı temel sınıf."""
    pass


def get_db():
    """Her request için bağımsız bir DB session üretir."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

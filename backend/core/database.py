# backend/core/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from core.config import settings

engine = create_engine(
    settings.DATABASE_URL.replace("postgresql://", "postgresql+psycopg://"),
    pool_pre_ping=True,
    connect_args={"prepare_threshold": None},
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

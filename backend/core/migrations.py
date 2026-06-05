# backend/core/migrations.py
from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def apply_lightweight_migrations(engine: Engine) -> None:
    """Apply tiny MVP-safe migrations before a real migration tool exists."""
    inspector = inspect(engine)
    table_names = inspector.get_table_names()

    if "vibes" in table_names:
        vibe_columns = {column["name"] for column in inspector.get_columns("vibes")}
        with engine.begin() as connection:
            if "is_golden_voice" not in vibe_columns:
                connection.execute(
                    text(
                        "ALTER TABLE vibes "
                        "ADD COLUMN is_golden_voice BOOLEAN NOT NULL DEFAULT FALSE"
                    )
                )

    if "users" not in table_names:
        return

    user_columns = {column["name"] for column in inspector.get_columns("users")}
    with engine.begin() as connection:
        if "password_hash" not in user_columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(255)")
            )
        if "daily_vibe_reset_at" not in user_columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN daily_vibe_reset_at TIMESTAMP")
            )
        if "display_name" not in user_columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN display_name VARCHAR(80)")
            )
        if "bio" not in user_columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN bio VARCHAR(240)")
            )
        if "is_private" not in user_columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN is_private BOOLEAN NOT NULL DEFAULT FALSE")
            )
        if "message_privacy" not in user_columns:
            connection.execute(
                text(
                    "ALTER TABLE users ADD COLUMN message_privacy "
                    "VARCHAR(20) NOT NULL DEFAULT 'everyone'"
                )
            )

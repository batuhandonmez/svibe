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

        _apply_security_indexes(connection, table_names)


def _apply_security_indexes(connection, table_names: list[str]) -> None:
    """Create stable indexes used by discovery, privacy, DM, and future RLS."""
    index_sql = {
        "users": [
            "CREATE INDEX IF NOT EXISTS idx_users_is_private ON users (is_private)",
            "CREATE INDEX IF NOT EXISTS idx_users_message_privacy ON users (message_privacy)",
        ],
        "vibes": [
            "CREATE INDEX IF NOT EXISTS idx_vibes_user_id ON vibes (user_id)",
            "CREATE INDEX IF NOT EXISTS idx_vibes_expires_at ON vibes (expires_at)",
            "CREATE INDEX IF NOT EXISTS idx_vibes_discovery ON vibes (expires_at, swipe_right_count)",
        ],
        "vibe_listens": [
            "CREATE INDEX IF NOT EXISTS idx_vibe_listens_user_id ON vibe_listens (user_id)",
            "CREATE INDEX IF NOT EXISTS idx_vibe_listens_vibe_id ON vibe_listens (vibe_id)",
        ],
        "vibe_swipes": [
            "CREATE INDEX IF NOT EXISTS idx_vibe_swipes_user_id ON vibe_swipes (user_id)",
            "CREATE INDEX IF NOT EXISTS idx_vibe_swipes_vibe_id ON vibe_swipes (vibe_id)",
        ],
        "follows": [
            "CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows (follower_id)",
            "CREATE INDEX IF NOT EXISTS idx_follows_following_id ON follows (following_id)",
            "CREATE INDEX IF NOT EXISTS idx_follows_status ON follows (status)",
        ],
        "dm_threads": [
            "CREATE INDEX IF NOT EXISTS idx_dm_threads_user_low_id ON dm_threads (user_low_id)",
            "CREATE INDEX IF NOT EXISTS idx_dm_threads_user_high_id ON dm_threads (user_high_id)",
        ],
        "dm_messages": [
            "CREATE INDEX IF NOT EXISTS idx_dm_messages_thread_id ON dm_messages (thread_id)",
            "CREATE INDEX IF NOT EXISTS idx_dm_messages_sender_id ON dm_messages (sender_id)",
            "CREATE INDEX IF NOT EXISTS idx_dm_messages_created_at ON dm_messages (created_at)",
        ],
    }

    for table_name, statements in index_sql.items():
        if table_name not in table_names:
            continue
        for statement in statements:
            connection.execute(text(statement))

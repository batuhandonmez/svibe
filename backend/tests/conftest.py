import os
from pathlib import Path


TEST_DB = Path(__file__).resolve().parent / ".svibe_test.sqlite3"

os.environ.setdefault("DATABASE_URL", f"sqlite:///{TEST_DB.as_posix()}")
os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("RATE_LIMIT_ENABLED", "false")

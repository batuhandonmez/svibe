import os
from pathlib import Path


TEST_DB = Path(__file__).resolve().parent / ".svibe_test.sqlite3"

os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB.as_posix()}"
os.environ["ENVIRONMENT"] = "test"
os.environ["RATE_LIMIT_ENABLED"] = "false"

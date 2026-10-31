import os

import pytest
from alembic import command
from alembic.config import Config

# Downgrading to base wipes the schema: only ever run against a *_test database.
if not os.environ.get("DATABASE_URL", "").endswith("_test"):
    pytest.skip("DATABASE_URL must point to a *_test database", allow_module_level=True)


def test_migrations_upgrade_downgrade_roundtrip() -> None:
    cfg = Config("alembic.ini")
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")

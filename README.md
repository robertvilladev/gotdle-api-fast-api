# Gotdle API

REST API built with **FastAPI**, **PostgreSQL**, and **SQLAlchemy** (async). Includes JWT authentication, database migrations via Alembic, and dependency management via `uv`.

## Tech Stack

| Layer | Tool |
|---|---|
| Framework | [FastAPI](https://fastapi.tiangolo.com/) |
| Server | [Uvicorn](https://www.uvicorn.org/) (ASGI) |
| Database | PostgreSQL |
| ORM | [SQLAlchemy 2](https://docs.sqlalchemy.org/) (async) |
| Migrations | [Alembic](https://alembic.sqlalchemy.org/) |
| Auth | JWT via `python-jose` + `passlib[bcrypt]` |
| Config | `pydantic-settings` (reads from `.env`) |
| Logging | [Loguru](https://loguru.readthedocs.io/) |
| Package manager | [uv](https://docs.astral.sh/uv/) |

## Project Structure

```
gotdle-api-fast-api/
├── main.py                  # App entry point, CORS, router registration
├── .env                     # Local secrets (gitignored — never commit this)
├── pyproject.toml           # Project dependencies (managed by uv)
├── uv.lock                  # Pinned lockfile (commit this)
├── alembic/                 # Database migrations
│   └── versions/            # Auto-generated migration files
└── app/
    ├── core/
    │   ├── config.py        # Settings loaded from .env
    │   └── security.py      # JWT helpers, password hashing
    ├── db/
    │   ├── base.py          # SQLAlchemy async engine + Base class
    │   └── session.py       # get_db() dependency
    ├── models/              # SQLAlchemy ORM models (DB tables)
    ├── schemas/             # Pydantic schemas (request/response shapes)
    ├── routers/             # FastAPI route handlers
    └── dependencies.py      # Shared dependencies (e.g. get_current_user)
```

## Prerequisites

- Python 3.12+
- PostgreSQL running locally (or via Docker)
- [uv](https://docs.astral.sh/uv/) installed

Install `uv` (if not already):
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Local Setup

### 1. Clone and install dependencies

```bash
git clone <repo-url>
cd gotdle-api-fast-api
uv sync          # creates .venv and installs all dependencies from uv.lock
```

### 2. Configure environment variables

Create a `.env` file in the root:

```env
APP_NAME=Gotdle API
DEBUG=True
SECRET_KEY=your-generated-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
DATABASE_URL=postgresql+asyncpg://postgres:yourpassword@localhost:5432/gotdle_db
```

Generate a secure secret key:
```bash
uv run python -c "import secrets; print(secrets.token_hex(32))"
```

### 3. Run database migrations

```bash
uv run alembic upgrade head
```

### 4. Start the development server

```bash
uv run uvicorn main:app --reload
```

The API will be available at:
- **API**: http://localhost:8000
- **Interactive docs (Swagger)**: http://localhost:8000/docs
- **Alternative docs (ReDoc)**: http://localhost:8000/redoc

## API Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/` | No | Health check |
| `POST` | `/auth/register` | No | Register new user |
| `POST` | `/auth/login` | No | Login, returns JWT token |
| `GET` | `/users/me` | JWT | Get current user profile |

## Running with Docker

Docker runs the API and PostgreSQL together in isolated containers — no local Postgres install needed.

```bash
# Build the image and start all services (db + api)
docker compose up --build

# Run in the background
docker compose up --build -d

# View logs
docker compose logs -f api

# Stop everything (data is preserved)
docker compose down

# Stop everything AND wipe the database volume
docker compose down -v
```

On first start, the API container automatically runs `alembic upgrade head` before starting the server, so the database schema is always in sync.

The API and Swagger docs are available at the same URLs: http://localhost:8000 and http://localhost:8000/docs.

> **Note**: When running locally (without Docker), `DATABASE_URL` in `.env` uses `localhost` as the host. Docker overrides this to use `db` (the internal service name) automatically — you don't need to change anything.

## Dependency Management (uv)

`uv` manages the virtual environment and dependencies. It replaces manually editing `requirements.txt`.

```bash
uv add <package-name>      # add a new package
uv remove <package-name>   # remove a package
uv sync                    # install all deps (e.g. after cloning)
uv run <command>           # run any command inside .venv
```

> `uv run uvicorn ...` automatically activates `.venv` before running. You never need `source .venv/bin/activate` manually.

## Database Migrations (Alembic)

```bash
# After modifying a model, generate a new migration
uv run alembic revision --autogenerate -m "describe your change"

# Apply all pending migrations
uv run alembic upgrade head

# Roll back the last migration
uv run alembic downgrade -1

# Check current migration version
uv run alembic current
```

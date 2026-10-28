# Gotdle API

Backend for **Gotdle**, a daily Game of Thrones guessing game inspired by
[loldle.net](https://loldle.net/) and [narutodle.net](https://narutodle.net/).
It serves the content library (characters, quotes, …), picks one daily answer per
game mode, and checks players' guesses. The frontend is
[gotdle-vue3](https://github.com/robertvilladev/gotdle-vue3).

> Status: **Phase 0 (foundations)**. Only the project setup and the (parked) auth
> endpoints exist. See the [roadmap](ROADMAP.md).

Built with **FastAPI**, **PostgreSQL** and **SQLAlchemy** (async), with migrations via
Alembic and dependency management via `uv`. Agent/contributor conventions are in
[CLAUDE.md](CLAUDE.md).

## Tech Stack

| Layer | Tool |
|---|---|
| Framework | [FastAPI](https://fastapi.tiangolo.com/) |
| Server | [Uvicorn](https://www.uvicorn.org/) (ASGI) |
| Database | PostgreSQL 17 |
| ORM | [SQLAlchemy 2](https://docs.sqlalchemy.org/) (async) |
| Migrations | [Alembic](https://alembic.sqlalchemy.org/) |
| Auth (parked) | JWT via `python-jose` + `passlib[bcrypt]` |
| Config | `pydantic-settings` (reads from `.env`) |
| Logging | [Loguru](https://loguru.readthedocs.io/) |
| Package manager | [uv](https://docs.astral.sh/uv/) |
| Lint / format / types | [ruff](https://docs.astral.sh/ruff/), [mypy](https://mypy-lang.org/) (strict) |
| Tests | pytest + pytest-asyncio + httpx2, against real Postgres |

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
tests/                       # pytest suite (DB tests need a *_test database)
```

## Prerequisites

- Python 3.14 (uv installs it for you)
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

- **API**: <http://localhost:8000>
- **Interactive docs (Swagger)**: <http://localhost:8000/docs>
- **Alternative docs (ReDoc)**: <http://localhost:8000/redoc>

## Checks and tests

```bash
uv run ruff check .          # lint
uv run ruff format .         # format
uv run mypy .                # type-check (strict)

# Tests hit a real Postgres. Create the test DB once:
docker compose exec db createdb -U postgres gotdle_test
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/gotdle_test uv run pytest
```

Tests that touch the database are skipped unless `DATABASE_URL` ends in `_test`, so a
dev database is never wiped. CI runs all of this on every PR. What deserves a
test is described in the roadmap's testing policy.

## API Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/` | No | Health check |
| `POST` | `/auth/register` | No | Register new user (parked for MVP) |
| `POST` | `/auth/login` | No | Login, returns JWT token (parked for MVP) |
| `GET` | `/users/me` | JWT | Get current user profile (parked for MVP) |

Planned game endpoints (Phase 2): `GET /modes`, `GET /daily/{mode}`,
`POST /daily/{mode}/guess`, `GET /characters/search?q=`.

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

> **Upgrading from Postgres 16:** the database volume can't be read by Postgres 17.
> Run `docker compose down -v` once (this wipes local data) before `up`.

This setup also includes CloudBeaver for a modern visual database UI at <http://localhost:8978>.

After opening CloudBeaver, create a PostgreSQL connection with:

- **Host**: `db` (if CloudBeaver runs in Docker) or `localhost` (from your host machine)
- **Port**: `5432`
- **Database**: `gotdle_db`
- **Username**: `postgres`
- **Password**: `password`

On first start, the API container automatically runs `alembic upgrade head` before starting the server, so the database schema is always in sync.

The API and Swagger docs are available at the same URLs: <http://localhost:8000> and <http://localhost:8000/docs>.

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

When developing with Docker, generate migration files on your host machine (in this repo), not inside the running `api` container.

Reason:

- The container runs as a non-root user, so creating new files under `/app` can fail.
- The project files are copied into the image at build time, so new files created inside the container are not persisted back to your repo.

If your local `.env` DB credentials do not match Docker Postgres credentials, use a one-off override to generate migrations against the Docker database:

```bash
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/gotdle_db \
uv run alembic revision --autogenerate -m "describe your change"
```

Then rebuild/start Docker so the API image includes the new migration file:

```bash
docker compose up --build -d
```

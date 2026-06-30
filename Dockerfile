# ── Stage 1: Builder ─────────────────────────────────────────────────────────
# We use a full Python image just to install dependencies into a virtual env.
# This stage is thrown away after — nothing extra ends up in the final image.
FROM python:3.12-slim AS builder

# Copy uv binary directly from its official image (no need to install it via pip)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy only the dependency files first.
# Docker caches each layer — if these files don't change, uv sync is skipped on rebuild.
COPY pyproject.toml uv.lock ./

# Install dependencies into .venv inside /app
# --frozen: fail if uv.lock is out of sync with pyproject.toml (good for CI/prod)
# --no-cache: don't store uv's download cache inside the image
# --no-dev: skip development-only tools (linters, test runners, etc.)
RUN uv sync --frozen --no-cache --no-dev


# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
# Start fresh from a clean slim image — no build tools, no uv, no cache.
# This is what actually runs in production.
FROM python:3.12-slim AS runtime

WORKDIR /app

# Copy the pre-built virtual environment from the builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy the application source code
COPY . .

# Add the venv's bin folder to PATH so Python/uvicorn/alembic are found without prefix
ENV PATH="/app/.venv/bin:$PATH"

# Run as a non-root user — standard security practice for containers
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

EXPOSE 8000

# Default command: just start the server.
# Migrations are handled by docker-compose (see command: in docker-compose.yml)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

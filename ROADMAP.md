# Gotdle Roadmap: backend

Gotdle is a daily guessing game set in the Game of Thrones world, inspired by
[loldle.net](https://loldle.net/) and [narutodle.net](https://narutodle.net/).
Every day each game mode has one answer. It's the same answer for every player,
and it resets at 00:00 UTC.

Each repo has its own roadmap with the **same phase numbers**:

- Backend: this file
- Frontend: [gotdle-vue3/ROADMAP.md](https://github.com/robertvilladev/gotdle-vue3/blob/main/ROADMAP.md)

Tick the checkbox in the same PR that finishes the work.

## MVP goal

> A player opens Gotdle, plays today's **Classic** (guess the character) and
> **Quote** challenges, gets per-guess feedback, and their streak persists
> in their browser. New content and new modes can be added **by adding data,
> not by redesigning the schema**.

**In MVP:** Classic mode, Quote mode, daily rotation, a seeded content library, deployment.
**After MVP:** Scene → season mode (images), accounts, global stats, admin UI, more modes.

## Backend design rules

1. **One content library, many modes.** `characters` is the hub; `quotes`, `scenes`
   and `seasons` reference it. A mode is a way of asking about that content,
   not its own data silo.
2. **Comparable attributes live on the character**, for example house, gender,
   status, origin region, first/last season and affiliations. Classic compares
   them one by one.
3. **The daily challenge is a row, not a cron job.** `daily_challenges(mode, date, answer_id)`
   has a unique key on `(mode, date)`. The first request of the day picks and
   stores the answer: a deterministic pick that excludes recent answers.
4. **Content is versioned in git.** Seed files (YAML/JSON) live in this repo and an
   idempotent import loads them. Content changes are reviewed like code.
5. **Answers never leave the server before they're solved.** Guesses are checked
   here and only feedback is returned.
6. **No accounts in MVP.** The existing auth code is parked.

## Testing policy (TDD, without slop)

Write the test first **for logic that can silently be wrong**:

- daily selection: deterministic, no repeats within N days, one answer under
  concurrent first requests;
- guess feedback: correct / partial / wrong, higher / lower for seasons;
- content import: idempotent, rejects invalid data and dangling references;
- one API contract test per endpoint (happy path + the important errors);
- migrations apply and roll back on a clean database.

Tests that touch the database run against **real Postgres**, never mocks.
**Don't** test schemas, config or framework wiring. If deleting a test
wouldn't let a real bug ship, the test shouldn't exist. CI target: **< 2 min**.

## Decisions

| # | Decision | Outcome |
|---|---|---|
| B1 | Framework | FastAPI |
| B2 | Python / packages | Python 3.14, **uv** |
| B3 | Database | PostgreSQL 17 |
| B4 | ORM / migrations | SQLAlchemy 2 (async, asyncpg) + Alembic |
| B5 | Lint / format / types | ruff + mypy |
| B6 | Tests | pytest + pytest-asyncio + httpx2. Real Postgres: `docker compose` locally, service container in CI |
| B7 | Auth | parked for MVP. When it's needed, replace `python-jose`/`passlib` with `pyjwt`/`pwdlib` |
| B8 | Images (post-MVP) | object storage + CDN, URLs stored in the DB |
| B9 | Hosting | open, decide in Phase 4 |

---

## Phase 0: Foundations

### 0.1 Tooling (setup PR)
- [x] Audit; write `CLAUDE.md`, `README.md`, `ROADMAP.md`
- [x] Python 3.14 everywhere (`.python-version`, `Dockerfile`), deps upgraded
- [x] Postgres 17 in `docker-compose.yml`
- [x] ruff, mypy, pytest set up; migration round-trip test
- [x] CI: ruff, mypy, pytest against Postgres

### 0.2 Data sourcing research
Goal: know where the starter content (characters, quotes, images) comes from and
under what license **before** designing the schema. Output: `docs/data-sources.md`
with a recommendation for each content type.

Leads to check. These haven't been verified yet, so confirm each one is still
online, how complete it is, and its license:

| Source | What it may give us | Notes |
|---|---|---|
| [jeffreylancaster/game-of-thrones](https://github.com/jeffreylancaster/game-of-thrones) | Show-based JSON: characters, houses, episodes, **scenes with timestamps and characters**, locations | Probably the best starting point for Classic + Scene. Check the license |
| [Wikidata](https://www.wikidata.org/) (SPARQL) | Structured character data: family, allegiance, actor | CC0, safe to reuse |
| [Game of Thrones Fandom wiki](https://gameofthrones.fandom.com/) (MediaWiki API) | Infobox data: status, seasons, culture, allegiance, and portraits | Text is CC BY-SA (needs attribution). Images are HBO's |
| [An API of Ice and Fire](https://anapioficeandfire.com/) | Characters, houses, books | **Books**, not the show. Good for houses/regions |
| [ThronesAPI](https://thronesapi.com/) | ~50 main characters with portrait URLs | Small, show-based |
| [Game of Thrones Quotes API](https://gameofthronesquotes.xyz/) | Quotes with character + house | Starter for Quote mode |
| Kaggle datasets (episode scripts / subtitles, deaths, battles) | Script lines → quotes; deaths → status | Check each dataset's license |
| [TMDB API](https://developer.themoviedb.org/) | **Episode stills per season**, cast photos | Free key; attribution required; check the image terms. Best lead for Scene mode |

- [ ] Evaluate each lead: coverage, quality, license, and whether it's still available
- [ ] Decide the **image strategy**. Images are HBO-copyrighted, so compare
      hotlinking from an API CDN (TMDB) with self-hosting, plus the attribution
      and takedown risk. Default: no self-hosted HBO images in MVP (MVP modes
      are text-only)
- [ ] Prototype a one-off script (`scripts/`, not app code) that turns the chosen
      sources into our seed format, and commit its output as the starter seed
- [ ] Write `docs/data-sources.md` (sources, licenses, attribution text, refresh steps)

## Phase 1: Content model and data
- [ ] Data model doc + ERD (`docs/data-model.md`): `characters`, `houses`, `seasons`,
      `quotes`, `game_modes`, `daily_challenges`
- [ ] Alembic migrations for the schema
- [ ] Seed format + idempotent `import` command (TDD: idempotency, validation)
- [ ] Seed: ~100 main characters with all Classic attributes
- [ ] Seed: ~300 quotes linked to characters

## Phase 2: Daily engine + Classic
- [ ] Daily answer selection (TDD: deterministic, no recent repeats, safe under concurrency)
- [ ] Guess comparison for Classic (TDD: every attribute type)
- [ ] `GET /modes`: list the active modes
- [ ] `GET /daily/{mode}`: today's challenge metadata (no answer)
- [ ] `POST /daily/{mode}/guess`: feedback for one guess
- [ ] `GET /characters/search?q=`: autocomplete
- [ ] CORS limited to the frontend origin(s)

## Phase 3: Quote mode
- [ ] Quote challenge reusing the daily engine + guess feedback
- [ ] Hint data (season/episode) exposed progressively

## Phase 4: Launch
- [ ] Hosting picked; container deploy + managed Postgres; migrations on deploy
- [ ] Error monitoring, structured logs
- [ ] Rate limiting on the guess endpoint

## Post-MVP
- Scene → season mode (images in object storage + CDN)
- Accounts + cross-device streaks (unpark auth, swap to `pyjwt`/`pwdlib`)
- Global "% of players solved today"
- Admin UI for content

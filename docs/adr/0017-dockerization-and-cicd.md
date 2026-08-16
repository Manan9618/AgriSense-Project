# ADR 0017: Dockerization — a monorepo build context, and two bugs only real verification caught

## Status
Accepted — Week 18

## Context
The project plan's Week 18 asks for a `Dockerfile` + `docker-compose.yml` for the backend, and
extending the existing GitHub Actions CI (`lint` + `backend-test`, from Week 1) with build and
deploy stages, verified via a local `docker build`/`docker run` — not just written and assumed to
work. That verification requirement mattered: two real bugs only showed up when actually running
the built image, not from reading the Dockerfile.

## Decision

**The Docker build context is the repo root, not `backend/`.** `backend/`'s seed command depends
on `content/treatment_recommendations.json`, a sibling directory shared with the mobile app
(`docs/adr/0001-monorepo-structure.md`). A naive `docker build backend/` never has access to
`content/` at all — the first build attempt failed exactly this way
(`CommandError: /content/treatment_recommendations.json not found`) because `COPY . .` from a
`backend/`-scoped context can't reach a path outside it; Docker fundamentally cannot `COPY` from
outside the build context under any configuration. The fix: `backend/Dockerfile` is written
assuming a repo-root context (`COPY backend/ .` then `COPY content/ /app/content/`, replicating
the same repo-relative layout `BASE_DIR.parent / "content"` already expects locally), and
`backend/docker-compose.yml` sets `build.context: ..` so `docker compose up` from `backend/` still
works without anyone needing to remember the right `-f`/context flags by hand. `.dockerignore`
moved to the repo root to match (a `.dockerignore` next to the Dockerfile has no effect unless it's
also the build context root) and excludes `ml/`/`mobile/`/docs to keep the build context small.

**SQLite stays, deliberately not replaced with Postgres.** Switching database engines is a real
decision with its own testing surface (a new dependency, connection pooling, migration behavior
differences) that's out of scope for "add a Dockerfile" — see ADR 0013's and ADR 0015's same
posture on not fabricating infrastructure readiness beyond what's actually been validated. SQLite
persists via a bind-mounted **directory** (`./data:/app/backend/data`, `DJANGO_DB_PATH` env var
added to `config/settings.py` to point there), not the file itself.

**Two bugs found only by actually running the container, not by reading the Dockerfile:**
1. **A file-vs-directory bind mount mismatch.** The first `docker-compose.yml` bind-mounted
   `./db.sqlite3:/app/backend/db.sqlite3` directly. When `db.sqlite3` doesn't already exist on the
   host, Docker created it as a **directory**, not an empty file — SQLite then failed with
   `unable to open database file`, a confusing error with no obvious connection to the actual
   cause. The fix is the `DJANGO_DB_PATH`-configurable directory mount above: a directory bind
   mount has no such ambiguity regardless of whether the host path pre-exists.
2. **`${VAR:-}` still sets the variable.** `docker-compose.yml` originally had
   `DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY:-}` intending "use the container's own fallback if
   unset on the host" — but Compose's `environment:` mapping always injects the key into the
   container's environment, just substituted to an empty string when the host var is absent. That
   is not the same as leaving it unset: `os.environ.get("DJANGO_SECRET_KEY", <fallback>)` returns
   the empty string it *found*, never reaching the fallback, and Django 5.2 raises
   `ImproperlyConfigured: The SECRET_KEY setting must not be empty` the first time a request needs
   it (surfaced as an opaque 500 on `/api/prices/compare/`, not at container startup). Fixed by
   giving the Compose-level default a real (if clearly-labeled insecure/dev-only) string instead
   of empty, mirroring `config/settings.py`'s own existing local-dev fallback pattern.

Both were caught by the exact verification loop the plan asked for: build the image, run it, hit a
real endpoint, read the actual error — not by inspecting the YAML.

**CI extended with `ml-test`, `mobile-test`, and `docker-build`**, alongside the existing `lint`/
`backend-test` from Week 1 — none of `ml/scripts/tests/` (Week 16), the mobile test suite (Weeks
4-17), or a Docker build had ever run in CI before this. `docker-build`'s smoke test is the same
build → run → seed → hit a real endpoint → assert on `is_auto_suggested` sequence just verified
locally, plus running the full `manage.py test` suite *inside* the built image as an additional
check that the production-shaped image (not just the dev venv) is sound.

**`deploy` is `workflow_dispatch`-only and credential-gated, not wired to a real target.** There is
no deployed backend (see `docs/pilot/pilot-launch-readiness.md`'s same point) and no hosting
credentials exist. The job never runs on a normal push/PR, and when manually triggered, checks for
a `DEPLOY_HOST` secret; finding none, it stops with a clear warning explaining why, rather than
guessing at a deploy target that doesn't exist. This satisfies the plan's "build (and deploy)
stages" literally — the stage exists, is documented, and is gated — without fabricating
infrastructure this project doesn't have.

## Consequences
- `docker compose up` from `backend/` is now the documented way to run a production-shaped backend
  locally, alongside (not replacing) the `manage.py runserver` dev quickstart.
- Anyone standing up a real deployment must supply a real `DJANGO_SECRET_KEY` (via a `.env` file
  next to `docker-compose.yml` or their platform's secrets mechanism) — the Compose-level fallback
  is explicitly labeled insecure/dev-only, matching `config/settings.py`'s own convention.
- The `mobile-test` CI job is the first time this project's Flutter suite runs on Linux rather than
  this development machine's macOS — `mobile/README.md` already claimed this would work without
  the macOS-specific dylib workaround, but that claim was untested until this CI job actually runs
  on GitHub's infrastructure.
- A real Postgres migration, real deploy credentials, and real hosting all remain explicitly future
  work — this ADR intentionally doesn't pretend otherwise.

#!/bin/sh
# Runs migrations before every container start — safe to run repeatedly
# (Django tracks applied migrations), and means a fresh SQLite volume gets
# its schema created automatically on first `docker compose up` rather than
# needing a separate manual step. Does NOT run seed_treatment_recommendations
# automatically: seeding is idempotent too, but re-running it on every
# restart is unnecessary work for something that only changes when
# content/treatment_recommendations.json does — run it manually (see
# backend/README section in the top-level README) after content changes.
set -e

python manage.py migrate --noinput

exec "$@"

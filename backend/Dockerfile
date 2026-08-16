# Built with the repo root as build context, not backend/ — this monorepo's
# `content/` directory (shared between this backend's seed command and the
# mobile app's bundled copy, see docs/adr/0001-monorepo-structure.md) lives
# outside backend/, so the image needs both. Build/run via
# `docker compose up` from backend/ (docker-compose.yml already points its
# build context at `..` for this reason) rather than `docker build .`
# from inside backend/.
FROM python:3.12-slim

WORKDIR /app/backend

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .
COPY content/ /app/content/

# Default DJANGO_DB_PATH target (docker-compose.yml mounts a volume here) —
# created so `docker run` without compose/a volume still works, SQLite just
# creates the file inside it.
RUN mkdir -p data

# SECRET_KEY falls back to config/settings.py's insecure dev default when
# unset (fine here — collectstatic never touches the database or needs a
# real key, and the real value is supplied at `docker run`/compose time).
RUN python manage.py collectstatic --noinput

EXPOSE 8000

RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]

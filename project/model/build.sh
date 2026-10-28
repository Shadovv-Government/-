#!/usr/bin/env bash
set -euo pipefail

MODEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$MODEL_DIR/.." && pwd)"

if [[ -n "${DATABASE_URL:-}" ]]; then
  command -v psql >/dev/null 2>&1 || { echo 'Для DATABASE_URL необходим psql.' >&2; exit 1; }
  psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$MODEL_DIR/build.sql"
else
  command -v docker >/dev/null 2>&1 || { echo 'Docker не найден: запустите локальную базу или задайте DATABASE_URL и установите psql.' >&2; exit 1; }
  cd "$PROJECT_DIR"
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U hack -d marketplace < "$MODEL_DIR/build.sql"
fi

#!/usr/bin/env bash
set -euo pipefail
# Запуск из каталога project: bash ../qa/run_audit.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker compose exec -T postgres psql -X -U hack -d marketplace \
  -v ON_ERROR_STOP=1 -f - < "$DIR/01_raw_audit.sql" > "$DIR/raw_audit.txt" 2>&1
printf 'Аудит выполнен: %s/raw_audit.txt\n' "$DIR"

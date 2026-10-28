#!/usr/bin/env bash
# Запускать на отдельной локальной базе, где raw уже загружен.
# Пересоздаёт core дважды и НЕ использует --reset.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p checkpoint/results
OUT="$(mktemp -d "${ROOT}/checkpoint/results/run-XXXXXXXX")"
echo "Результаты: $OUT"

if [[ -n "${DATABASE_URL:-}" ]]; then
  psql_run() { PGOPTIONS='-c max_parallel_workers_per_gather=0' psql -X -q -v ON_ERROR_STOP=1 "$DATABASE_URL" "$@"; }
else
  psql_run() { docker compose exec -T -e PGOPTIONS='-c max_parallel_workers_per_gather=0' postgres psql -X -q -v ON_ERROR_STOP=1 -U hack -d marketplace "$@"; }
fi

psql_run -c 'SELECT version();' > "$OUT/version.txt"
psql_run --csv < ../qa/02_raw_fingerprint.sql > "$OUT/raw_before.csv"
bash model/build.sh > "$OUT/build_first.log" 2>&1
psql_run --csv < computer-1/core_fingerprint.sql > "$OUT/core_first.csv"
bash model/build.sh > "$OUT/build_second.log" 2>&1
psql_run --csv < computer-1/core_fingerprint.sql > "$OUT/core_second.csv"
psql_run --csv < ../qa/02_raw_fingerprint.sql > "$OUT/raw_after.csv"
diff -u "$OUT/raw_before.csv" "$OUT/raw_after.csv" > "$OUT/raw_diff.txt"
diff -u "$OUT/core_first.csv" "$OUT/core_second.csv" > "$OUT/core_diff.txt"

psql_run --csv < computer-1/01_monthly_revenue.sql > "$OUT/q1.csv"
psql_run --csv < computer-3/answers/02_sellers.sql > "$OUT/q2.csv"
psql_run --csv < computer-3/answers/03_average_order.sql > "$OUT/q3.csv"
psql_run --csv < computer-2/q4_customers.sql > "$OUT/q4.csv"
psql_run --csv < answers/computer-4/q5_revenue_by_category.sql > "$OUT/q5.csv"
psql_run --csv < answers/computer-4/q5_checks.sql > "$OUT/q5_checks.csv"
psql_run --csv < quality/computer-4/01_feature_preservation.sql > "$OUT/feature_checks.csv"
psql_run --csv < quality/computer-4/02_q5_raw_vs_core.sql > "$OUT/q5_raw_vs_core.csv"
psql_run < computer-2/key_relationship_checks.sql > "$OUT/key_relationship_checks.txt" 2>&1
psql_run < computer-3/quality/financial_reconciliation.sql > "$OUT/financial_reconciliation.txt" 2>&1
python3 checkpoint/validate_results.py "$OUT" | tee "$OUT/control_checks.txt"
echo "Проверки завершены: $OUT"

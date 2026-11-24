#!/usr/bin/env bash
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$dir")"
load_date=""
log_file="$dir/checks.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --load-date) load_date="${2:?Specify a load date}"; shift 2 ;;
    --log-file) log_file="${2:?Specify a log file}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ ! "$load_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
   ! date -d "$load_date" +%F >/dev/null 2>&1; then
  echo "Use --load-date YYYY-MM-DD" >&2
  exit 2
fi

mkdir -p "$(dirname "$log_file")"
run_id="$(date -u +%Y%m%dT%H%M%S)-$$"
log() {
  printf '%s run_id=%s load_date=%s %s\n' "$(date -u +%FT%TZ)" "$run_id" "$load_date" "$*" |
    tee -a "$log_file"
}
trap 'log "FAILED (exit $?)"' ERR

log "START"
for table in customers products product_categories order_items; do
  log "raw/$table"
  bash "$root/spark/raw/$table/$table.sh"
done
for table in orders payments events; do
  log "raw/$table"
  bash "$root/spark/raw/$table/$table.sh" --load-date "$load_date"
done
for step in staging/stg_orders staging/stg_payments intermediate/int_orders_with_payments marts/fct_orders; do
  table="${step##*/}"
  log "$step"
  bash "$root/spark/$step/$table.sh" --load-date "$load_date"
done

spark-submit \
  --master spark://spark-master:7077 \
  --name "check-shop" \
  --deploy-mode client \
  --conf spark.executor.instances=1 \
  --conf spark.executor.cores=1 \
  --conf spark.executor.memory=1g \
  --conf spark.driver.memory=1g \
  --conf spark.dynamicAllocation.enabled=false \
  "$dir/check.py" --load-date "$load_date" --log-file "$log_file" --run-id "$run_id"
log "PASSED"

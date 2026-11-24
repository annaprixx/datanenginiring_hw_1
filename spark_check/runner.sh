#!/usr/bin/env bash
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -eq 0 ]]; then
  set -- 2026-03-05 2026-03-06
fi

status=0
for load_date in "$@"; do
  if [[ -f /.dockerenv ]]; then
    bash "$dir/run_check.sh" --load-date "$load_date" || status=1
  else
    docker exec ubuntu-vm bash /home/student/study/store_hse/spark_check/run_check.sh \
      --load-date "$load_date" || status=1
  fi
done
exit "$status"

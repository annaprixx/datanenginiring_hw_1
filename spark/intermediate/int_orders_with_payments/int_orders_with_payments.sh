#!/usr/bin/env bash
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec spark-submit \
  --master spark://spark-master:7077 \
  --name "int-orders-with-payments" \
  --deploy-mode client \
  --conf spark.executor.instances=1 \
  --conf spark.executor.cores=1 \
  --conf spark.executor.memory=1g \
  --conf spark.driver.memory=1g \
  --conf spark.dynamicAllocation.enabled=false \
  "$dir/int_orders_with_payments.py" "$@"

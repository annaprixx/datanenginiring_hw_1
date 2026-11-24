import argparse
import json
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
import os

from pyspark.sql import SparkSession
from pyspark.sql import functions as F


def make_spark():
    builder = SparkSession.builder
    for key, env in (
        ("endpoint", "MINIO_ENDPOINT"),
        ("access.key", "MINIO_ROOT_USER"),
        ("secret.key", "MINIO_ROOT_PASSWORD"),
    ):
        if env in os.environ:
            builder.config(f"spark.hadoop.fs.s3a.{key}", os.environ[env])
    spark = (
        builder.config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
        .config("spark.sql.session.timeZone", "UTC")
        .config("spark.sql.sources.partitionOverwriteMode", "dynamic")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")
    return spark


def read_postgres(spark, query):
    return (
        spark.read.format("jdbc")
        .option("url", f"jdbc:postgresql://postgres:5432/{os.environ['POSTGRES_DB']}")
        .option("user", os.environ["POSTGRES_USER"])
        .option("password", os.environ["POSTGRES_PASSWORD"])
        .option("driver", "org.postgresql.Driver")
        .option("query", query)
        .load()
    )


def read_window(spark, path, column, start, end, include_pending=False):
    day = F.col(column)
    condition = (day >= start) & (day < end)
    if include_pending:
        condition = condition | day.isNull()
    return spark.read.parquet(f"s3a://de-course/{path}").filter(condition)


def same_rows(name, data, expected, keys):
    if set(data.columns) != set(expected.columns):
        raise ValueError(f"{name}: unexpected columns: {data.columns}")
    data = data.select(*expected.columns)
    if data.groupBy(*keys).count().filter("count > 1").take(1):
        raise ValueError(f"{name}: duplicate keys {keys}")
    if data.exceptAll(expected).take(1) or expected.exceptAll(data).take(1):
        raise ValueError(f"{name}: rows differ from the reference")
    cols = dict(data.dtypes)
    for col in ("order_date", "paid_dt", "ordered_at", "is_refund", "is_test_order"):
        if col in cols and cols[col] != dict(expected.dtypes)[col]:
            raise ValueError(f"{name}: unexpected type for {col}: {cols[col]}")


def check_raw(spark, start, end):
    tables = {
        "customers": ["customer_id"],
        "products": ["product_id"],
        "product_categories": ["category_id"],
        "order_items": ["order_id", "product_id"],
    }
    for name, keys in tables.items():
        data = spark.read.parquet(f"s3a://de-course/raw/{name}")
        expected = read_postgres(spark, f"SELECT * FROM public.{name}")
        same_rows(name, data, expected, keys)

    tables = [
        ("orders", "order_id", "order_created_at", "order_created_dt"),
        ("payments", "payment_id", "paid_at", "paid_dt"),
        ("events", "event_id", "event_time", "event_dt"),
    ]
    for name, key, time, col in tables:
        pending = name == "payments"
        where = f"{time} >= TIMESTAMP '{start}' AND {time} < TIMESTAMP '{end}'"
        if pending:
            where = f"(({where}) OR {time} IS NULL)"
        if name == "events":
            data = spark.read.parquet("s3a://de-course/raw/events")
            if data.filter(F.col("event_dt").isNull()).take(1):
                raise ValueError("events: null partition")
        data = read_window(spark, f"raw/{name}", col, start, end, pending)
        query = f"SELECT *, CAST({time} AS date) AS {col} FROM public.{name} WHERE {where}"
        same_rows(name, data, read_postgres(spark, query), [key])


def check_models(spark, start, end):
    orders = read_window(spark, "raw/orders", "order_created_dt", start, end)
    payments = read_window(spark, "raw/payments", "paid_dt", start, end, True)
    orders.createOrReplaceTempView("raw_orders")
    payments.createOrReplaceTempView("raw_payments")

    orders = read_window(spark, "staging/stg_orders", "order_date", start, end)
    payments = read_window(spark, "staging/stg_payments", "paid_dt", start, end, True)
    same_rows("stg_orders", orders, spark.sql("""
        SELECT order_id, customer_id, CAST(order_created_at AS timestamp) AS ordered_at,
            CAST(order_created_at AS date) AS order_date, status AS order_status,
            total_amount AS order_amount, status = 'test' AS is_test_order
        FROM raw_orders
    """), ["order_id"])
    same_rows("stg_payments", payments, spark.sql("""
        SELECT payment_id, order_id, paid_at, payment_status, amount,
            payment_status = 'success' AND amount < 0 AS is_refund,
            CAST(paid_at AS date) AS paid_dt
        FROM raw_payments
    """), ["payment_id"])

    orders.createOrReplaceTempView("orders")
    payments.createOrReplaceTempView("payments")
    expected = spark.sql("""
        WITH summary AS (
            SELECT order_id,
                COUNT(*) FILTER (WHERE payment_status = 'success' AND NOT is_refund) AS successful_payments_count,
                SUM(amount) FILTER (WHERE payment_status = 'success' AND NOT is_refund) AS paid_amount,
                -SUM(amount) FILTER (WHERE is_refund) AS refunded_amount,
                MIN(paid_at) FILTER (WHERE payment_status = 'success' AND NOT is_refund) AS first_paid_at,
                COUNT(*) FILTER (WHERE payment_status = 'success') AS success_operations_count,
                COUNT(*) FILTER (WHERE payment_status = 'failed') AS failed_operations_count,
                COUNT(*) FILTER (WHERE payment_status = 'pending') AS pending_operations_count
            FROM payments GROUP BY order_id
        )
        SELECT o.*, COALESCE(p.successful_payments_count, 0) AS successful_payments_count,
            COALESCE(p.paid_amount, 0) AS paid_amount,
            COALESCE(p.refunded_amount, 0) AS refunded_amount,
            COALESCE(p.paid_amount, 0) - COALESCE(p.refunded_amount, 0) AS net_paid_amount,
            p.first_paid_at,
            o.order_status = 'paid' AND COALESCE(p.successful_payments_count, 0) > 0 AS is_confirmed,
            COALESCE(p.success_operations_count, 0) AS success_operations_count,
            COALESCE(p.failed_operations_count, 0) AS failed_operations_count,
            COALESCE(p.pending_operations_count, 0) AS pending_operations_count
        FROM orders o LEFT JOIN summary p USING (order_id)
    """)
    data = read_window(spark, "intermediate/int_orders_with_payments", "order_date", start, end)
    same_rows("int_orders_with_payments", data, expected, ["order_id", "order_date"])

    data.createOrReplaceTempView("order_totals")
    fact = read_window(spark, "marts/fct_orders", "order_date", start, end)
    same_rows("fct_orders", fact, spark.sql("""
        SELECT order_id, customer_id, order_date, ordered_at, order_status, order_amount,
            paid_amount, refunded_amount, net_paid_amount, successful_payments_count,
    first_paid_at, is_confirmed
        FROM order_totals WHERE NOT is_test_order
    """), ["order_id", "order_date"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--load-date", type=date.fromisoformat, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--log-file", type=Path, required=True)
    args = parser.parse_args()
    end = args.load_date
    start = end - timedelta(days=3)
    spark = make_spark()
    try:
        for check in (check_raw, check_models):
            record = {
                "time": datetime.now(timezone.utc).isoformat(),
                "run_id": args.run_id,
                "load_date": end.isoformat(),
                "check": check.__name__,
                "status": "PASSED",
            }
            try:
                check(spark, start, end)
            except Exception as error:
                record.update(status="FAILED", message=str(error))
                raise
            finally:
                with args.log_file.open("a", encoding="utf-8") as log:
                    log.write(json.dumps(record, ensure_ascii=False) + "\n")
                print(f"{record['status']} {record['check']} {end}", flush=True)
    finally:
        spark.stop()


if __name__ == "__main__":
    main()

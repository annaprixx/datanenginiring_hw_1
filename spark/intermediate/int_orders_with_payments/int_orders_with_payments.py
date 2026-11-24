import argparse
from datetime import date, timedelta

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


def window():
    parser = argparse.ArgumentParser()
    parser.add_argument("--load-date", type=date.fromisoformat, required=True)
    args = parser.parse_args()
    return args.load_date - timedelta(days=3), args.load_date


def read_window(spark, path, column, start, end, include_pending=False):
    day = F.col(column)
    condition = (day >= start) & (day < end)
    if include_pending:
        condition = condition | day.isNull()
    return spark.read.parquet(f"s3a://de-course/{path}").filter(condition)


def write_partitions(spark, data, path, column, days, include_pending=False):
    # Dynamic overwrite replaces partitions with rows. Clear stale partitions
    # in the selected window that are now empty (including the pending snapshot).
    folder = spark._jvm.org.apache.hadoop.fs.Path(path)
    fs = folder.getFileSystem(spark.sparkContext._jsc.hadoopConfiguration())
    days = list(days)
    if include_pending:
        days.append(None)

    data = data.persist()
    try:
        present = {row[0] for row in data.select(column).distinct().collect()}
        data.write.mode("overwrite").partitionBy(column).parquet(path)
        for day in days:
            if day not in present:
                value = day if day is not None else "__HIVE_DEFAULT_PARTITION__"
                part = spark._jvm.org.apache.hadoop.fs.Path(folder, f"{column}={value}")
                if fs.exists(part) and not fs.delete(part, True):
                    raise OSError(f"Could not clear empty partition: {part}")
    finally:
        data.unpersist()


def main():
    start, end = window()
    spark = make_spark()
    try:
        orders = read_window(spark, "staging/stg_orders", "order_date", start, end)
        payments = read_window(
            spark, "staging/stg_payments", "paid_dt", start, end, include_pending=True
        )
        status = F.col("payment_status")
        refund = F.col("is_refund")
        paid = (status == "success") & ~refund
        summary = payments.groupBy("order_id").agg(
            F.count(F.when(paid, 1)).alias("successful_payments_count"),
            F.sum(F.when(paid, F.col("amount"))).alias("paid_amount"),
            (-F.sum(F.when(refund, F.col("amount")))).alias("refunded_amount"),
            F.min(F.when(paid, F.col("paid_at"))).alias("first_paid_at"),
            F.count(F.when(status == "success", 1)).alias("success_operations_count"),
            F.count(F.when(status == "failed", 1)).alias("failed_operations_count"),
            F.count(F.when(status == "pending", 1)).alias("pending_operations_count"),
        )
        cols = [
            "successful_payments_count", "paid_amount", "refunded_amount",
            "success_operations_count", "failed_operations_count", "pending_operations_count",
        ]
        data = orders.join(summary, "order_id", "left").fillna(0, subset=cols)
        data = data.withColumn(
            "net_paid_amount", F.col("paid_amount") - F.col("refunded_amount")
        ).withColumn(
            "is_confirmed",
            (F.col("order_status") == "paid") & (F.col("successful_payments_count") > 0),
        )
        days = [start + timedelta(days=day) for day in range(3)]
        path = "s3a://de-course/intermediate/int_orders_with_payments"
        write_partitions(spark, data, path, "order_date", days)
    finally:
        spark.stop()


if __name__ == "__main__":
    main()

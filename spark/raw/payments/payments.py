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


def sink_has_data(spark, path):
    folder = spark._jvm.org.apache.hadoop.fs.Path(path)
    fs = folder.getFileSystem(spark.sparkContext._jsc.hadoopConfiguration())
    if not fs.exists(folder):
        return False

    files = fs.listFiles(folder, True)
    while files.hasNext():
        if files.next().getPath().getName().endswith(".parquet"):
            return spark.read.parquet(path).limit(1).count() > 0
    return False


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
    path = "s3a://de-course/raw/payments"
    spark = make_spark()
    try:
        where = ""
        if sink_has_data(spark, path):
            where = f"WHERE ((paid_at >= TIMESTAMP '{start}' " \
                    f"AND paid_at < TIMESTAMP '{end}') OR paid_at IS NULL)"
        query = f"SELECT * FROM public.payments {where}"
        data = read_postgres(spark, query).withColumn("paid_dt", F.to_date("paid_at"))
        days = [start + timedelta(days=day) for day in range(3)]
        # Dynamic overwrite preserves partitions outside the selected window.
        # NULL payment dates are stored in __HIVE_DEFAULT_PARTITION__.
        write_partitions(spark, data, path, "paid_dt", days, include_pending=True)
    finally:
        spark.stop()


if __name__ == "__main__":
    main()

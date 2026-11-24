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


def main():
    spark = make_spark()
    try:
        # There is no timestamp in order_items for a three-day window.
    # Replace the full snapshot without partitions.
        query = "SELECT * FROM public.order_items"
        data = read_postgres(spark, query)
        data.write.mode("overwrite").parquet("s3a://de-course/raw/order_items")
    finally:
        spark.stop()


if __name__ == "__main__":
    main()

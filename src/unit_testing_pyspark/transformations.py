"""Transformations for the unit testing with PySpark example."""

from pyspark.sql import DataFrame
from pyspark.sql.functions import col


def filter_active_users(df: DataFrame) -> DataFrame:
    """Filter on active users."""
    return df.filter(col("status") == "active")

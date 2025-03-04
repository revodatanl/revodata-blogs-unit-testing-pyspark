"""Tests for the transformations module."""

import pytest
from databricks.connect import DatabricksSession
from pyspark.sql import SparkSession

from unit_testing_pyspark.transformations import filter_active_users


@pytest.fixture(scope="session")
def spark() -> SparkSession:
    """Fixture for creating a SparkSession instance."""
    return DatabricksSession.builder.getOrCreate()


def test_filter_active_users(spark: SparkSession) -> None:
    """Tests whether the input DataFrame is filtered on active users."""
    user_data = [(1, "active"), (2, "deactivated")]
    user_df = spark.createDataFrame(user_data, ["id", "status"])
    result = filter_active_users(user_df).collect()

    assert len(result) == 1
    assert result[0]["id"] == 1

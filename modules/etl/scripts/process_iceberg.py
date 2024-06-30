import sys
import boto3

from datetime import datetime
from pyspark.sql import SparkSession

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job


# @params: [JOB_NAME,TABLE_NAME, GOLD_BUCKET_NAME, INPUT_DATABASE, OUTPUT_DATABASE]
args = getResolvedOptions(
    sys.argv, 
    ['JOB_NAME', 
     'TABLE_NAME',
	 'GOLD_BUCKET_NAME',
     'INPUT_DATABASE',
	 'OUTPUT_DATABASE',
     'USERNAME'
    ]
)

catalog_nm = "glue_catalog"
save_to_dynamo = False

table = f"{args['USERNAME']}_{args['TABLE_NAME']}"
output_table = f"iceberg_{args['TABLE_NAME']}"
gold_bucket = f"s3://{args['GOLD_BUCKET_NAME']}"
input_database = args['INPUT_DATABASE']
output_database = args['OUTPUT_DATABASE']
username = args['USERNAME']

output_path = f"{gold_bucket}/{output_database}/{table}/"
aws_account_id = boto3.client('sts').get_caller_identity().get('Account')

spark = SparkSession.builder \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.defaultCatalog", catalog_nm) \
        .config(f"spark.sql.catalog.{catalog_nm}", "org.apache.iceberg.spark.SparkCatalog") \
        .config(f"spark.sql.catalog.{catalog_nm}.warehouse","file:///tmp/spark-warehouse") \
        .config(f"spark.sql.catalog.{catalog_nm}.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog") \
        .config(f"spark.sql.catalog.{catalog_nm}.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
        .config(f"spark.sql.catalog.{catalog_nm}.glue.lakeformation-enabled", "true") \
        .config(f"spark.sql.catalog.{catalog_nm}.glue.id", aws_account_id) \
        .config("spark.sql.iceberg.handle-timestamp-without-timezone", "true") \
        .getOrCreate()
sc = spark.sparkContext
glueContext = GlueContext(sc)
job = Job(glueContext)

print("Start query")
result_df = glueContext.create_dynamic_frame.from_catalog(database=input_database, table_name=table).toDF()

result_df.createOrReplaceTempView(f"tmp_{table}")
print("Start create temp view")

write_sql = f"""
    CREATE OR REPLACE TABLE {catalog_nm}.{output_database}.{output_table} 
    USING iceberg
    LOCATION "{output_path}"
    TBLPROPERTIES ("format-version"="2", "write_compression"="gzip")
    AS SELECT * FROM tmp_{table};
"""

spark.sql(write_sql)

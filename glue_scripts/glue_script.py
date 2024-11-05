import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Load data from Glue catalog
dynamic_frame = glueContext.create_dynamic_frame.from_catalog(database="etl_data_catalog", table_name="your_table")

# Transform data (Convert JSON to Parquet)
parquet_data = glueContext.write_dynamic_frame.from_options(
    frame=dynamic_frame,
    connection_type="s3",
    connection_options={"path": "s3://${aws_s3_bucket.data_bucket.bucket}/output/"},
    format="parquet"
)

job.commit()

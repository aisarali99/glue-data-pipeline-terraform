provider "aws" {
  region = "us-east-1"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# S3 Buckets for Script, Data, and Temporary Storage
resource "aws_s3_bucket" "script_bucket" {
  bucket = "etl-script-bucket-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = "etl-data-bucket-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket" "temp_bucket" {
  bucket = "etl-temp-bucket-${random_string.suffix.result}"
  force_destroy = true
}

# IAM Role for Glue
resource "aws_iam_role" "glue_role" {
  name = "glue_service_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "glue.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  })
}

# Attach policy for Glue role
resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Add extra permissions for Glue role
resource "aws_iam_role_policy" "glue_policy_extra" {
  name = "glue_extra_policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "glue:CreateDatabase",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateJob",
          "glue:GetJob",
          "glue:GetJobs",
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchCreatePartition",
          "glue:GetPartition",
          "glue:GetPartitions"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_service_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "etl_function" {
  function_name = "ETL-Function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "etl_lambda.lambda_handler"
  runtime       = "python3.8"
  filename      = "../lambda_scripts/etl_lambda.zip"
  source_code_hash = filebase64sha256("../lambda_scripts/etl_lambda.zip")
  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data_bucket.bucket
    }
  }
}

# Glue Database (Data Catalog)
resource "aws_glue_catalog_database" "etl_database" {
  name = "etl_data_catalog"
}

# Glue Crawler for Data Catalog
resource "aws_glue_crawler" "data_crawler" {
  name          = "data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.etl_database.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_bucket.bucket}/"
  }
}

# Glue Job for ETL
resource "aws_glue_job" "etl_job" {
  name     = "glue-etl-job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.script_bucket.bucket}/glue_script.py"
  }

  default_arguments = {
    "--TempDir" = "s3://${aws_s3_bucket.temp_bucket.bucket}/temp/"
  }
}

# Upload Glue Script to S3
resource "aws_s3_object" "glue_script_upload" {
  bucket = aws_s3_bucket.script_bucket.bucket
  key    = "glue_script.py"
  source = "../glue_scripts/glue_script.py"
}

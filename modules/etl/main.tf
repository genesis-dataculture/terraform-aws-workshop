resource "aws_iam_role" "glue_role" {
  name = "${var.username}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "glue_policy" {
  name = "${var.username}-glue-policy"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:*"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${var.raw_bucket_name}",
          "arn:aws:s3:::${var.raw_bucket_name}/*",
          "arn:aws:s3:::${var.gold_bucket_name}",
          "arn:aws:s3:::${var.gold_bucket_name}/*",
        ]
      },
      {
        Action = [
          "glue:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_glue_catalog_database" "glue_database" {
  name = "${var.username}"
}


resource "aws_glue_crawler" "crawler" {
  name = "${var.username}-ticker-crawler"

  database_name = aws_glue_catalog_database.glue_database.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${var.raw_bucket_name}/${var.username}/"
  }

  configuration = jsonencode({
    "Version" : 1.0,
    "Grouping" : {
      "TableGroupingPolicy" : "CombineCompatibleSchemas"
      TableLevelConfiguration = 3
    },
    "CrawlerOutput" : {
      "Partitions" : {
        "AddOrUpdateBehavior" : "InheritFromTable"
      }
    }
  })

  table_prefix = "${var.username}_"

  schema_change_policy {
    delete_behavior = "DEPRECATE_IN_DATABASE"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }
}


resource "aws_s3_object" "process_iceberg_glue_script" {
  bucket = var.raw_bucket_name
  key    = "glue_scripts/${var.username}/process_iceberg.py"
  source = "modules/etl/scripts/process_iceberg.py"
  etag   = filemd5("modules/etl/scripts/process_iceberg.py")
}


resource "aws_glue_job" "process_iceberg" {
  for_each = toset(var.tickers)

  name        = "process_${each.key}"
  role_arn    = aws_iam_role.glue_role.arn
  command {
    script_location = "s3://${var.raw_bucket_name}/glue_scripts/${var.username}/process_iceberg.py"
    python_version  = "3"
    name            = "glueetl"
  }
  glue_version = "4.0"
  max_retries  = 0
  timeout      = 60
  max_capacity = 2.0
  number_of_workers = null
  default_arguments = {
    "--job-bookmark-option" = "job-bookmark-disable" 
    "--enable-metrics" = ""
    "--enable-glue-datacatalog" = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter" = "true"
    "--datalake-formats" = "iceberg"
    "--GOLD_BUCKET_NAME" = var.gold_bucket_name
    "--INPUT_DATABASE" = aws_glue_catalog_database.glue_database.name
    "--OUTPUT_DATABASE" = aws_glue_catalog_database.glue_database.name
    "--TABLE_NAME" = each.key
    "--USERNAME" = var.username
  }
}
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
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${var.raw_bucket_name}",
          "arn:aws:s3:::${var.raw_bucket_name}/*"
        ]
      },
      {
        Action = [
          "glue:*"
        ],
        Effect   = "Allow",
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
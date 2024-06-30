module "ingestion" {
  source = "./modules/ingestion"
  username = var.username
  raw_bucket_name = var.raw_bucket_name
}

module "etl" {
  source = "./modules/etl"
  username = var.username
  raw_bucket_name = var.raw_bucket_name
  gold_bucket_name = var.gold_bucket_name
}

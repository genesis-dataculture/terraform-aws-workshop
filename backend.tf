terraform {
    backend "s3" {
        region = "us-east-1"
        bucket = "genesis-terraform-workshop-bucket"
        key = "workshop/lmeazzini/terraform.tfstate"
    }
}
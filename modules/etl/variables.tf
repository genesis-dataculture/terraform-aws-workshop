variable "username" {
  description = "User name"
}

variable "raw_bucket_name" {
  description = "User name"
}

variable "gold_bucket_name" {
  description = "gold bucket_name"
}

variable "tickers" {
  description = "List of tickers to process"
  type        = list(string)
  default     = ["bitcoin", "ethereum"]
}
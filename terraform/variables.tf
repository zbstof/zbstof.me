variable "aws_region" {
  description = "AWS region for the site buckets"
  type        = string
  default     = "eu-central-1"
}

variable "site_domain" {
  description = "Hostname to serve, and the S3 bucket name (they must match)"
  type        = string
  default     = "zbstof.me"
}

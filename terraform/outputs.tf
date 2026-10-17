output "site_url" {
  description = "Public URL of the site"
  value       = "https://${var.site_domain}/"
}

output "website_endpoint" {
  description = "S3 website endpoint; the apex CNAME in ~/Play/zbstof.me-infra points at it"
  value       = aws_s3_bucket_website_configuration.site.website_endpoint
}

output "www_website_endpoint" {
  description = "S3 website endpoint of the www redirect bucket; the www CNAME points at it"
  value       = aws_s3_bucket_website_configuration.www.website_endpoint
}

output "files_published" {
  description = "Number of objects uploaded to the bucket"
  value       = length(aws_s3_object.site)
}

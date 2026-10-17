terraform {
  # use_lockfile below needs 1.10 or newer. Pinned in .terraform-version.
  required_version = ">= 1.10"

  # Same bucket as the other projects, one key per project.
  backend "s3" {
    bucket       = "zbstof-terraform-state"
    key          = "zbstof.me/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  site_dir = "${path.module}/../web"
  files    = fileset(local.site_dir, "**")

  content_types = {
    html = "text/html; charset=utf-8"
    css  = "text/css; charset=utf-8"
    ico  = "image/x-icon"
    png  = "image/png"
    svg  = "image/svg+xml"
  }

  # Cloudflare caches .css at the edge but not .html, so pages reference the
  # stylesheet with a ?v=<md5> stamp: a changed stylesheet gets a new URL, and
  # a year-long max-age stays safe.
  css_v = substr(filemd5("${local.site_dir}/style.css"), 0, 10)

  html_rendered = {
    for f in local.files : f => templatefile("${local.site_dir}/${f}", { css_v = local.css_v })
    if endswith(f, ".html")
  }

  etags = merge(
    { for f in local.files : f => filemd5("${local.site_dir}/${f}") if !endswith(f, ".html") },
    { for f, c in local.html_rendered : f => md5(c) },
  )

  cache_control = {
    html = "public, max-age=300"
    css  = "public, max-age=31536000, immutable"
  }
}

# ---------------------------------------------------------------- site bucket
# The bucket name must equal the hostname: S3 website endpoints route by Host.
resource "aws_s3_bucket" "site" {
  bucket = var.site_domain
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
      }
    ]
  })

  # A policy granting public read is rejected while the access block is still on.
  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_object" "site" {
  for_each = local.files

  bucket = aws_s3_bucket.site.id
  key    = each.value

  # Pages are rendered through templatefile to carry the stylesheet stamp;
  # every other file is uploaded byte for byte.
  source  = endswith(each.value, ".html") ? null : "${local.site_dir}/${each.value}"
  content = lookup(local.html_rendered, each.value, null)
  etag    = local.etags[each.value]

  content_type = lookup(local.content_types, lower(reverse(split(".", each.value))[0]), "application/octet-stream")

  cache_control = lookup(
    local.cache_control,
    lower(reverse(split(".", each.value))[0]),
    "public, max-age=3600"
  )
}

# ---------------------------------------------------------------- www redirect
# www.zbstof.me gets its own empty bucket that 301-redirects every request to
# the apex, keeping the path.
resource "aws_s3_bucket" "www" {
  bucket = "www.${var.site_domain}"
}

resource "aws_s3_bucket_website_configuration" "www" {
  bucket = aws_s3_bucket.www.id

  redirect_all_requests_to {
    host_name = var.site_domain
    protocol  = "https"
  }
}

# ---------------------------------------------------------------- dns
# The zbstof.me and www.zbstof.me CNAMEs to these website endpoints live in
# ~/Play/zbstof.me-infra. S3 website endpoints speak HTTP only, so the zone's
# SSL mode must stay Flexible.

provider "aws" {
  region = "us-east-1" # Change to your preferred AWS region
}

# S3 Bucket
# resource "aws_s3_bucket" "selected" {
#   bucket = "guiling2025" # Must be globally unique
# }

# Disable ACLs and enforce ownership
# resource "aws_s3_bucket_ownership_controls" "selected" {
#   bucket = aws_s3_bucket.selected.id
#   rule {
#     object_ownership = "BucketOwnerEnforced"
#   }
# }

# Configure public access (required for static selected)
resource "aws_s3_bucket_public_access_block" "selected" {
  bucket = aws_s3_bucket.selected.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy for public read access
resource "aws_s3_bucket_policy" "selected" {
  bucket = aws_s3_bucket.selected.id
  policy = data.aws_iam_policy_document.selected.json
}

data "aws_iam_policy_document" "selected" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.selected.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

locals {
  # Step 1: Get all files using fileset (glob pattern)
  all_files = fileset(".", "**/*")

  # Step 2: Filter files using regex
  filtered_files = [
    for file in local.all_files :
    file if can(regex("\\.(jpg|png|html)$", file))
  ]

  # Step 3: Create source paths for filtered files
  static_files = {
    for file in local.filtered_files :
    file => {
      source_path = "${file}"
      content_type = lookup({
        "html" = "text/html",
        "jpg"  = "image/jpeg",
        "png"  = "image/png"
      }, split(".", file)[1], "application/octet-stream")
    }
  }
}


resource "aws_s3_object" "bulk_upload" {
  for_each     = local.static_files
  bucket       = aws_s3_bucket.selected.id
  key          = each.key
  source       = each.value.source_path
  content_type = each.value.content_type
}

output "static_files" {
  description = "List of filtered files to be uploaded"
  value       = local.static_files
}

# S3 Bucket for Static Website Hosting
resource "aws_s3_bucket_website_configuration" "selected" {
  bucket = aws_s3_bucket.selected.id

  index_document {
    suffix = "index.html"
  }
}

# S3 Bucket Policy to Allow Public Read Access
resource "aws_s3_bucket_policy" "public_read_access" {
  bucket = aws_s3_bucket.selected.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.selected.bucket}/*"
    }
  ]
}
POLICY
}

# Upload an Example Index.html File
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.selected.id
  key          = "index.html"
  content      = "<h1>Welcome to My Static Website</h1>"
  content_type = "text/html"
}

resource "aws_s3_bucket" "selected" {
  bucket = "bauhinia.link"
}

data "aws_route53_zone" "test_zone" {
  name = "bauhinia.link"
}

resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.test_zone.id
  name    = "bauhinia.link"
  type    = "A"

  alias {
    name = aws_s3_bucket.selected.website_domain
    # "s3-website-us-east-1.amazonaws.com"
    # 
    zone_id                = aws_s3_bucket.selected.hosted_zone_id
    evaluate_target_health = false
  }
}



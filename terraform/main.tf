# -------------------------------------------------------
# AWS SECTION - S3 Bucket to host the weather app
# -------------------------------------------------------

# i am creating an S3 bucket to store and serve my weather app files
# force_destroy = true so terraform can delete it even when it has files inside
# i learned this the hard way in project 2 when destroy failed on non empty buckets
resource "aws_s3_bucket" "weather_app" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Project = "weather-app"
    Cloud   = "AWS"
  }
}

# by default AWS blocks all public access to S3 buckets for security
# i need to turn this off because my weather app needs to be publicly accessible
resource "aws_s3_bucket_public_access_block" "weather_app" {
  bucket = aws_s3_bucket.weather_app.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# this tells S3 to serve my files as a website instead of just storing them
# index.html loads by default when someone visits the bucket URL
resource "aws_s3_bucket_website_configuration" "weather_app" {
  bucket = aws_s3_bucket.weather_app.id

  index_document {
    suffix = "index.html"
  }

  # if there is an error just load index.html again
  error_document {
    key = "index.html"
  }
}

# this policy allows anyone on the internet to read my app files
# without this nobody can access the website even with public access unblocked
resource "aws_s3_bucket_policy" "weather_app" {
  bucket     = aws_s3_bucket.weather_app.id
  depends_on = [aws_s3_bucket_public_access_block.weather_app]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.weather_app.arn}/*"
      }
    ]
  })
}

# uploading my three app files directly from my laptop to S3 using terraform
# etag uses filemd5 so terraform only re-uploads a file if its content changed
# if i only change app.js only that file gets uploaded not all three
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.weather_app.id
  key          = "index.html"
  source       = "../app/index.html"
  content_type = "text/html"
  etag         = filemd5("../app/index.html")
}

resource "aws_s3_object" "style" {
  bucket       = aws_s3_bucket.weather_app.id
  key          = "style.css"
  source       = "../app/style.css"
  content_type = "text/css"
  etag         = filemd5("../app/style.css")
}

resource "aws_s3_object" "appjs" {
  bucket       = aws_s3_bucket.weather_app.id
  key          = "app.js"
  source       = "../app/app.js"
  content_type = "application/javascript"
  etag         = filemd5("../app/app.js")
}

# -------------------------------------------------------
# AWS SECTION - CloudFront CDN Distribution
# -------------------------------------------------------

# i am creating a CloudFront distribution to serve my weather app globally
# without this my app only loads from one region which is slow for users far away
resource "aws_cloudfront_distribution" "weather_app" {
  enabled             = true
  default_root_object = "index.html"
  comment             = var.cloudfront_comment

  # telling cloudfront where to get the files from
  # i am pointing it to my S3 bucket website endpoint
  origin {
    domain_name = aws_s3_bucket_website_configuration.weather_app.website_endpoint
    origin_id   = "S3-weather-app"

    # S3 website endpoints only support http so cloudfront talks to S3 over http
    # but serves users over https - this is standard practice
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # this controls how cloudfront handles incoming requests
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-weather-app"

    # if someone visits over http they get redirected to https automatically
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # cache my app files at edge locations for 1 hour
    # after 1 hour cloudfront checks S3 for any updates
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # i want my weather app available to everyone worldwide
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # using cloudfront free default ssl certificate
  # this gives me https without buying a certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project = "weather-app"
    Cloud   = "AWS"
  }
}

# -------------------------------------------------------
# AZURE SECTION - Blob Storage to host the weather app
# -------------------------------------------------------

# i am creating a resource group to organize all my Azure resources
# in Azure everything must belong to a resource group - its like a folder
resource "azurerm_resource_group" "weather_app" {
  name     = var.azure_resource_group
  location = var.azure_location

  tags = {
    Project = "weather-app"
    Cloud   = "Azure"
  }
}

# i am creating an Azure storage account which is the container for blob storage
# account_tier = Standard and replication = LRS is the cheapest option for a portfolio project
# account_kind = StorageV2 is required for static website hosting on Azure
resource "azurerm_storage_account" "weather_app" {
  name                     = var.azure_storage_account
  resource_group_name      = azurerm_resource_group.weather_app.name
  location                 = azurerm_resource_group.weather_app.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # this enables static website hosting on Azure Blob Storage
  # same concept as S3 static website hosting but on Azure
  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }

  tags = {
    Project = "weather-app"
    Cloud   = "Azure"
  }
}

# uploading index.html to Azure Blob Storage
# storage_account_name references the account i just created above
resource "azurerm_storage_blob" "index" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.weather_app.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../app/index.html"
  content_type           = "text/html"
}

# uploading style.css to Azure Blob Storage
resource "azurerm_storage_blob" "style" {
  name                   = "style.css"
  storage_account_name   = azurerm_storage_account.weather_app.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../app/style.css"
  content_type           = "text/css"
}

# uploading app.js to Azure Blob Storage
resource "azurerm_storage_blob" "appjs" {
  name                   = "app.js"
  storage_account_name   = azurerm_storage_account.weather_app.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../app/app.js"
  content_type           = "application/javascript"
}

# -------------------------------------------------------
# ROUTE 53 SECTION - Hosted Zone and DNS Failover
# -------------------------------------------------------

# i am creating a hosted zone for my domain in Route 53
# this is where all my DNS records will live
# after terraform apply i need to copy the nameservers to Namecheap
resource "aws_route53_zone" "weather_app" {
  name = var.domain_name

  tags = {
    Project = "weather-app"
  }
}

# i am creating a health check that pings my CloudFront endpoint every 30 seconds
# if CloudFront stops responding 3 times in a row Route 53 switches to Azure
resource "aws_route53_health_check" "weather_app_aws" {
  fqdn              = aws_cloudfront_distribution.weather_app.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name    = "weather-app-aws-health-check"
    Project = "weather-app"
  }
}

# PRIMARY DNS record - points www.anil-weatherapp.online to CloudFront
# all traffic goes here normally when AWS is healthy
# i linked it to the health check so Route 53 knows when AWS goes down
resource "aws_route53_record" "primary" {
  zone_id        = aws_route53_zone.weather_app.zone_id
  name           = "www.${var.domain_name}"
  type           = "A"
  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.weather_app_aws.id

  alias {
    name                   = aws_cloudfront_distribution.weather_app.domain_name
    zone_id                = aws_cloudfront_distribution.weather_app.hosted_zone_id
    evaluate_target_health = true
  }
}

# SECONDARY DNS record - points www.anil-weatherapp.online to Azure Blob Storage
# this only activates when the primary health check fails 3 times
# this is my disaster recovery failover destination
resource "aws_route53_record" "secondary" {
  zone_id        = aws_route53_zone.weather_app.zone_id
  name           = "backup.${var.domain_name}"
  type           = "CNAME"
  set_identifier = "secondary"
  ttl            = 60

  failover_routing_policy {
    type = "SECONDARY"
  }

  # pointing to Azure Blob Storage website endpoint as the failover destination
  records = [azurerm_storage_account.weather_app.primary_web_host]
}
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
  aliases             = ["www.${var.domain_name}", "app.${var.domain_name}"]
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
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-weather-app"

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

  # i am using my own SSL certificate instead of the default CloudFront one
  # this allows HTTPS to work with my custom domain www.anil-weatherapp.online
  # sni-only is the modern standard and works with all browsers built after 2010
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.weather_app.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
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
# Standard LRS is the cheapest option and more than enough for a portfolio project
# StorageV2 is required for static website hosting on Azure
resource "azurerm_storage_account" "weather_app" {
  name                     = var.azure_storage_account
  resource_group_name      = azurerm_resource_group.weather_app.name
  location                 = azurerm_resource_group.weather_app.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # this enables static website hosting on Azure Blob Storage
  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }

  tags = {
    Project = "weather-app"
    Cloud   = "Azure"
  }
}

# uploading my three app files to Azure Blob Storage
# $web is the special container Azure creates for static website hosting
resource "azurerm_storage_blob" "index" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.weather_app.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../app/index.html"
  content_type           = "text/html"
}

resource "azurerm_storage_blob" "style" {
  name                   = "style.css"
  storage_account_name   = azurerm_storage_account.weather_app.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../app/style.css"
  content_type           = "text/css"
}

resource "azurerm_storage_blob" "appjs" {
  name                   = "app.js"
  storage_account_name   = azurerm_storage_account.weather_app.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../app/app.js"
  content_type           = "application/javascript"
}
# -------------------------------------------------------
# AZURE FRONT DOOR SECTION - CDN and SSL for Azure side
# -------------------------------------------------------

# i am using Azure Front Door Standard which is the modern replacement
# for Azure CDN classic which was deprecated by Microsoft
resource "azurerm_cdn_frontdoor_profile" "weather_app" {
  name                = "weather-app-frontdoor"
  resource_group_name = azurerm_resource_group.weather_app.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = {
    Project = "weather-app"
    Cloud   = "Azure"
  }
}

# i am creating a Front Door endpoint - this is my public facing URL
resource "azurerm_cdn_frontdoor_endpoint" "weather_app" {
  name                     = "weather-app-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.weather_app.id

  tags = {
    Project = "weather-app"
    Cloud   = "Azure"
  }
}

# i am creating an origin group that points to my Blob Storage
resource "azurerm_cdn_frontdoor_origin_group" "weather_app" {
  name                     = "weather-app-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.weather_app.id

  load_balancing {}
}

# i am creating an origin that points to my Azure Blob Storage website
resource "azurerm_cdn_frontdoor_origin" "weather_app" {
  name                           = "weather-app-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.weather_app.id
  host_name                      = azurerm_storage_account.weather_app.primary_web_host
  origin_host_header             = azurerm_storage_account.weather_app.primary_web_host
  https_port                     = 443
  http_port                      = 80
  enabled                        = true
  certificate_name_check_enabled = false
}

# i am creating a route that connects the endpoint to the origin group
resource "azurerm_cdn_frontdoor_route" "weather_app" {
  name                          = "weather-app-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.weather_app.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.weather_app.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.weather_app.id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  # i am linking my custom domain to this route
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.weather_app.id]
  link_to_default_domain          = false
}

# i am attaching my custom domain to Azure Front Door
# Azure provides a free managed SSL certificate for custom domains
resource "azurerm_cdn_frontdoor_custom_domain" "weather_app" {
  name                     = "weather-app-custom-domain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.weather_app.id
  host_name                = "app.${var.domain_name}"

  tls {
    certificate_type = "ManagedCertificate"
  }
}
# -------------------------------------------------------
# ACM CERTIFICATE SECTION - SSL for custom domain
# -------------------------------------------------------

# i am requesting a free SSL certificate for my custom domain
# this is required for HTTPS to work with CloudFront on a custom domain
# without this visitors get a security warning in their browser
resource "aws_acm_certificate" "weather_app" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}", "app.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Project = "weather-app"
  }

  # create new certificate before destroying old one
  lifecycle {
    create_before_destroy = true
  }
}

# i am automatically creating DNS validation records in Route 53
# this proves to AWS that i own the domain without any manual steps
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.weather_app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.weather_app.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# i am telling Terraform to wait until the certificate is fully validated
# before using it in CloudFront - otherwise deployment will fail
resource "aws_acm_certificate_validation" "weather_app" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.weather_app.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
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
# i am using app subdomain for failover routing
# this avoids the A record vs CNAME conflict on www
# both primary and secondary are CNAME type so Route 53 allows them on the same name
resource "aws_route53_record" "primary" {
  zone_id        = aws_route53_zone.weather_app.zone_id
  name           = "app.${var.domain_name}"
  type           = "CNAME"
  set_identifier = "primary"
  ttl            = 60

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.weather_app_aws.id
  records         = [aws_cloudfront_distribution.weather_app.domain_name]
}

# secondary record points to Azure - same CNAME type as primary
# activates automatically when primary health check fails
resource "aws_route53_record" "secondary" {
  zone_id        = aws_route53_zone.weather_app.zone_id
  name           = "app.${var.domain_name}"
  type           = "CNAME"
  set_identifier = "secondary"
  ttl            = 60

  failover_routing_policy {
    type = "SECONDARY"
  }

  records = [azurerm_cdn_frontdoor_endpoint.weather_app.host_name]
}

# www points to app subdomain
# users visit www.anil-weatherapp.online and get routed through the failover logic
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.weather_app.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 60
  records = ["app.${var.domain_name}"]
}

# i am adding Azure Front Door domain validation record to Route 53
# Azure needs this to prove i own app.anil-weatherapp.online
resource "aws_route53_record" "azure_frontdoor_validation" {
  zone_id = aws_route53_zone.weather_app.zone_id
  name    = "_dnsauth.app.${var.domain_name}"
  type    = "TXT"
  ttl     = 60
  records = ["_nz83yurs7j0vxnsiqjfb2j0oftskwze"]
}
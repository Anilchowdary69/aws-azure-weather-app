# -------------------------------------------------------
# OUTPUTS - important values printed after terraform apply
# -------------------------------------------------------

# i want to see my S3 bucket name after deployment
output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the weather app"
  value       = aws_s3_bucket.weather_app.id
}

# i want the S3 website URL to test the app directly on S3 before CloudFront
output "s3_website_url" {
  description = "Direct S3 static website URL"
  value       = "http://${aws_s3_bucket_website_configuration.weather_app.website_endpoint}"
}

# i want the CloudFront URL to test the app through the CDN
output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.weather_app.domain_name}"
}

# i want the CloudFront distribution ID for cache invalidation
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.weather_app.id
}

# i want the Azure storage account name after deployment
output "azure_storage_account_name" {
  description = "Name of the Azure storage account"
  value       = azurerm_storage_account.weather_app.name
}

# i want the Azure website URL to test the app directly on Azure
output "azure_website_url" {
  description = "Azure Blob Storage static website URL"
  value       = "https://${azurerm_storage_account.weather_app.primary_web_host}"
}
#i want the azure cdn url after deployment
output "azure_cdn_url" {
  description = "Azure Front Door endpoint URL"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.weather_app.host_name}"
}

# my domain name
output "domain_name" {
  description = "Custom domain name"
  value       = var.domain_name
}

# i need these nameservers to update Namecheap DNS settings
output "route53_nameservers" {
  description = "Route 53 nameservers - copy these to Namecheap"
  value       = aws_route53_zone.weather_app.name_servers
}
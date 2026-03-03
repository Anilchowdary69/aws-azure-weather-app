# AWS Configuration
variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to host the weather app"
  default     = "weather-app-aws-33454"
}

variable "cloudfront_comment" {
  description = "Comment for the CloudFront distribution"
  default     = "Weather App CDN Distribution"
}

# Azure Configuration
variable "azure_subscription_id" {
  description = "Azure subscription ID"
}

variable "azure_location" {
  description = "Azure region to deploy resources"
  default     = "East US"
}

variable "azure_resource_group" {
  description = "Name of the Azure resource group"
  default     = "weather-app-rg"
}

variable "azure_storage_account" {
  description = "Name of the Azure storage account"
  default     = "weatherapp6969"
}

# Route 53 Configuration
variable "domain_name" {
  description = "My custom domain name registered on Namecheap"
  default     = "your-domain.com"
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for your domain"
  default     = ""
}
output "website_url" {
  description = "Public URL of the static website"
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}

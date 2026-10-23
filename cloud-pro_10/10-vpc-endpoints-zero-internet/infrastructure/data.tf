data "aws_caller_identity" "current" {}

# ---------- The project's data bucket: readable ONLY through the VPC endpoint ----------
resource "aws_s3_bucket" "data" {
  bucket        = "${local.name_prefix}-data-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Anyone, even an admin on a laptop, is refused when reading confidential/ objects
# from outside the VPC endpoint. Writing and deleting stay allowed so Terraform can clean up.
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ReadConfidentialOnlyViaVpcEndpoint"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.data.arn}/confidential/*"
      Condition = { StringNotEquals = { "aws:SourceVpce" = aws_vpc_endpoint.s3.id } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.data]
}

# ---------- A second bucket the endpoint policy must block ----------
resource "aws_s3_bucket" "outside" {
  bucket        = "${local.name_prefix}-outside-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "outside" {
  bucket                  = aws_s3_bucket.outside.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "outside_hello" {
  bucket  = aws_s3_bucket.outside.id
  key     = "hello.txt"
  content = "If you can read this from inside the private VPC, the endpoint policy is not working.\n"
}

resource "aws_dynamodb_table" "events" {
  name         = "${local.name_prefix}-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }
}

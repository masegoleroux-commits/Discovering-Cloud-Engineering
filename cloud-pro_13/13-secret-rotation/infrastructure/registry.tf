# Stands in for the partner system that must accept each new key.
# It stores SHA-256 hashes only, so the table never holds a usable key.
resource "aws_dynamodb_table" "registry" {
  name         = "${local.name_prefix}-key-registry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key_hash"

  attribute {
    name = "key_hash"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

# The sandbox fixes DynamoDB at 1 read and 1 write capacity unit,
# so the table uses PROVISIONED mode instead of on-demand.
resource "aws_dynamodb_table" "notes" {
  name           = "${local.name_prefix}-notes"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "note_id"

  attribute {
    name = "note_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

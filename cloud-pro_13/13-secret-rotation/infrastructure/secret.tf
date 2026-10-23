# The first key. After this, only the rotation Lambda ever writes a new one.
resource "random_password" "initial_key" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "api_key" {
  name                    = "${local.name_prefix}/partner-api-key"
  description             = "API key the client app uses to call the partner API. Rotated automatically."
  recovery_window_in_days = 0 # practice project: delete immediately on destroy
}

resource "aws_secretsmanager_secret_version" "initial" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = random_password.initial_key.result

  lifecycle {
    ignore_changes = [secret_string, version_stages] # rotation owns the value from now on
  }
}

# Register the first key with the "partner" (hash only).
resource "aws_dynamodb_table_item" "initial_key" {
  table_name = aws_dynamodb_table.registry.name
  hash_key   = aws_dynamodb_table.registry.hash_key
  item = jsonencode({
    key_hash   = { S = sha256(random_password.initial_key.result) }
    version_id = { S = aws_secretsmanager_secret_version.initial.version_id }
  })

  lifecycle {
    ignore_changes = [item] # rotation revokes old keys; Terraform must not put this one back
  }
}

resource "aws_secretsmanager_secret_rotation" "api_key" {
  secret_id           = aws_secretsmanager_secret.api_key.id
  rotation_lambda_arn = aws_lambda_function.fn["rotation"].arn
  rotate_immediately  = false # the guide rotates on demand, so you can watch each step

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [aws_lambda_permission.secretsmanager, aws_dynamodb_table_item.initial_key]
}

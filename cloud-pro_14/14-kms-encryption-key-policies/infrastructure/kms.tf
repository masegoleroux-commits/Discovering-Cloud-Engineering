locals {
  # Written with jsonencode (not a data source) so the offline tests can inspect it.
  key_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        # Without this the key could become unmanageable. It lets IAM policies in this
        # account grant access, which is why an AdministratorAccess user can still use the key.
        Sid       = "EnableIamPolicies"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "KeyAdministratorsManageOnly"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.key_admin.arn }
        # Listed one by one on purpose. kms:Create* would include kms:CreateGrant, and
        # kms:PutKeyPolicy would let an admin rewrite the policy: either one lets an admin
        # give themselves Decrypt. Policy changes go through Terraform instead.
        Action = [
          "kms:CreateAlias", "kms:UpdateAlias", "kms:DeleteAlias", "kms:DescribeKey", "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus", "kms:List*", "kms:EnableKey", "kms:DisableKey", "kms:EnableKeyRotation",
          "kms:DisableKeyRotation", "kms:RotateKeyOnDemand", "kms:UpdateKeyDescription", "kms:RevokeGrant",
          "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
        ]
        Resource = "*"
      },
      {
        Sid       = "KeyUsersUseOnly"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.app.arn }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      },
    ]
  }
}

resource "aws_kms_key" "data" {
  description             = "${local.name_prefix}: encrypts the S3 bucket, DynamoDB table and SQS queue"
  enable_key_rotation     = true # new key material every year; old data still decrypts
  deletion_window_in_days = var.deletion_window_days
  policy                  = jsonencode(local.key_policy)
}

resource "aws_kms_alias" "data" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.data.key_id
}

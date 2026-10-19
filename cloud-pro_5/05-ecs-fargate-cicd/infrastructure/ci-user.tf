# Fallback for accounts that block OIDC providers (ci_auth = "access_keys").
# A dedicated IAM user with the SAME least-privilege permissions as the OIDC role.
# You create its access key yourself in the console, so the secret never
# appears in Terraform state, and you store it as two GitHub secrets.

resource "aws_iam_user" "github_ci" {
  count         = var.ci_auth == "access_keys" ? 1 : 0
  name          = "${local.name_prefix}-github-ci"
  force_destroy = true # lets destroy.sh delete the user even though it has an access key
}

resource "aws_iam_user_policy" "github_ci" {
  count  = var.ci_auth == "access_keys" ? 1 : 0
  name   = "${local.name_prefix}-github-ci"
  user   = aws_iam_user.github_ci[0].name
  policy = data.aws_iam_policy_document.github_deploy.json
}

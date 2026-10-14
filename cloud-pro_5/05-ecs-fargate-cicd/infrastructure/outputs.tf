output "app_url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.app.name
}

output "task_family" {
  value = aws_ecs_task_definition.app.family
}

output "github_deploy_role_arn" {
  description = "ci_auth = oidc: paste this into the AWS_DEPLOY_ROLE_ARN variable in GitHub"
  value       = var.ci_auth == "oidc" ? aws_iam_role.github_deploy[0].arn : "not used (ci_auth = access_keys)"
}

output "github_ci_user" {
  description = "ci_auth = access_keys: create an access key for this IAM user and save it as GitHub secrets"
  value       = var.ci_auth == "access_keys" ? aws_iam_user.github_ci[0].name : "not used (ci_auth = oidc)"
}

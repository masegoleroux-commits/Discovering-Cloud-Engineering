# 0004 GitHub Actions uses OIDC, not stored keys

Status: Accepted

## Context
GitHub Actions needs AWS permissions to push images and deploy. The common shortcut is to save an IAM user's access keys as GitHub secrets.

## Decision
Use OIDC federation. GitHub gives each workflow run a short-lived signed token; AWS checks it and returns temporary credentials for the `container-app-dev-github-deploy` role. The role's trust policy accepts only this repository's `main` branch.

## Alternatives rejected
- **Access keys in GitHub secrets:** long-lived keys that work from anywhere if leaked, and need manual rotation.

## Consequences
Nothing secret is stored in GitHub; the role ARN is not sensitive, so it's saved as a repository *variable*. The role can only push to one ECR repository, register task definitions, update one ECS service, and pass the two task roles. An account can have only one GitHub OIDC provider, so `create_github_oidc_provider = false` reuses an existing one.

## Update: fallback for accounts that block OIDC
My own AWS account belongs to an organisation whose service control policy denies `iam:ListOpenIDConnectProviders` and creating OIDC providers. So the project supports `ci_auth = "access_keys"`: a dedicated IAM user (`container-app-dev-github-ci`) with **the same least-privilege policy** as the OIDC role. I create its access key in the console, so the secret is never in Terraform state, and store it as GitHub secrets. It's weaker than OIDC (a long-lived key that works from anywhere if leaked), so the key is deleted with the user by `./scripts/destroy.sh` at the end of each session.


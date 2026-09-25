# 01 – Static Website on S3

Host a static website on Amazon S3, provisioned with Terraform.

## What it creates
- An S3 bucket with static website hosting enabled
- A bucket policy allowing public read of the site files
- An uploaded `index.html`

## Prerequisites
- An AWS account and the AWS CLI configured (`aws configure`)
- Terraform 1.5+

## Run it
```bash
terraform init
terraform plan -var="bucket_name=your-unique-bucket-name"
terraform apply -var="bucket_name=your-unique-bucket-name"
```
Terraform prints the `website_url` when it finishes. Open it in your browser.

## Clean up
```bash
terraform destroy -var="bucket_name=your-unique-bucket-name"
```

## What I learned
- The Terraform workflow: init, plan, apply, destroy
- How S3 static website hosting and bucket policies work
- Why public access blocks exist and when to relax them

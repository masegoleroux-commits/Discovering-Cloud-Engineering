#!/bin/bash
# Installs Nginx from the Amazon Linux repositories (reached through the S3 gateway endpoint)
# and serves a page showing which server and Availability Zone answered.
set -euxo pipefail
dnf install -y nginx

TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
meta() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
INSTANCE_ID=$(meta instance-id)
AZ=$(meta placement/availability-zone)

cat > /usr/share/nginx/html/index.html <<HTML
<!doctype html>
<html><head><title>edge-web</title></head>
<body style="font-family:sans-serif;max-width:40rem;margin:4rem auto">
<h1>Highly available web tier</h1>
<p>Served by <strong>$INSTANCE_ID</strong> in <strong>$AZ</strong>,
through CloudFront, AWS WAF and an Application Load Balancer.</p>
</body></html>
HTML
echo "ok" > /usr/share/nginx/html/health
echo "{\"instance\":\"$INSTANCE_ID\",\"az\":\"$AZ\"}" > /usr/share/nginx/html/whoami

sed -i 's/^\(\s*\)server_tokens.*//' /etc/nginx/nginx.conf
sed -i 's/http {/http {\n    server_tokens off;/' /etc/nginx/nginx.conf
systemctl enable --now nginx

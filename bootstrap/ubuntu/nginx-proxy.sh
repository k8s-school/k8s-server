#!/bin/bash

# Install and configure nginx as HTTPS proxy for cockpit
# Usage: K8S_IP=<target_ip> ./nginx-proxy.sh

set -euxo pipefail

# Check if K8S_IP is provided
if [ -z "${K8S_IP:-}" ]; then
  echo "ERROR: K8S_IP environment variable is required" >&2
  echo "Usage: K8S_IP=<target_ip> $0" >&2
  exit 1
fi

echo "=========================================="
echo "Setting up nginx HTTPS proxy to cockpit"
echo "Target k8s instance: $K8S_IP:9090"
echo "=========================================="

# Get public IP and setup nip.io domain
echo "Getting public IP..."
PUBLIC_IP=$(curl -s ifconfig.me)
NIP_DOMAIN="${PUBLIC_IP//./-}.nip.io"

echo "Public IP: $PUBLIC_IP"
echo "Domain: $NIP_DOMAIN"

# Update system and install packages
echo ""
echo "Installing packages..."
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx curl

# Create temporary SSL certificate
echo ""
echo "Creating temporary SSL certificate..."
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx-selfsigned.key \
  -out /etc/nginx/ssl/nginx-selfsigned.crt \
  -subj "/CN=$NIP_DOMAIN" 2>/dev/null

# Configure nginx
echo ""
echo "Configuring nginx..."

# Main cockpit proxy configuration
cat > /etc/nginx/sites-available/cockpit-proxy <<EOF
server {
    listen 80;
    server_name $NIP_DOMAIN;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $NIP_DOMAIN;

    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass https://$K8S_IP:9090;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_ssl_verify off;
        gzip off;
    }
}
EOF

# Kuard proxy configuration
cat > /etc/nginx/sites-available/kuard-proxy <<EOF
server {
    listen 80;
    server_name kuard.$NIP_DOMAIN;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name kuard.$NIP_DOMAIN;

    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Kuard redirections for i=0 to 9 (ports 8080-8089)
    location ~ ^/kuard-([0-9])/ {
        proxy_pass http://$K8S_IP:808\$1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_buffering off;
    }

    # Kuard redirections for i=10 to 19 (ports 8090-8099)
    location ~ ^/kuard-1([0-9])/ {
        proxy_pass http://$K8S_IP:809\$1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_buffering off;
    }
}
EOF

# Enable sites
ln -sf /etc/nginx/sites-available/cockpit-proxy /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/kuard-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and start nginx
echo ""
echo "Starting nginx..."
nginx -t
systemctl enable nginx
systemctl restart nginx

# Configure firewall (Ubuntu uses ufw)
echo ""
echo "Configuring firewall..."
ufw --force enable
ufw allow 'Nginx Full'
ufw allow 22

# Get Let's Encrypt certificate
echo ""
echo "Getting Let's Encrypt certificate..."
echo "This may take a few minutes..."

# Wait a bit for DNS propagation
sleep 10

certbot --nginx -d $NIP_DOMAIN --non-interactive --agree-tos --register-unsafely-without-email || {
    echo ""
    echo "WARNING: Failed to get Let's Encrypt certificate"
    echo "Server is accessible with self-signed certificate"
    echo "You can retry manually: certbot --nginx -d $NIP_DOMAIN"
}

# Setup auto-renewal
echo ""
echo "Setting up certificate auto-renewal..."
systemctl enable certbot.timer

echo ""
echo "=========================================="
echo "Nginx proxy setup completed!"
echo "=========================================="
echo "Cockpit accessible at: https://$NIP_DOMAIN"
echo "Proxying to: https://$K8S_IP:9090"
echo ""
echo "Test connection: curl -k https://$NIP_DOMAIN"
echo "=========================================="

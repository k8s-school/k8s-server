#!/bin/bash
set -e

echo "=========================================="
echo "Installation de Cockpit avec accès web HTTPS"
echo "=========================================="

# Récupération de l'IP publique
echo "Récupération de l'IP publique..."
PUBLIC_IP=$(curl -s ifconfig.me)
NIP_DOMAIN=$(echo $PUBLIC_IP | tr '.' '-').nip.io

echo "IP publique détectée: $PUBLIC_IP"
echo "Domaine nip.io: $NIP_DOMAIN"

# Installation de Cockpit
echo ""
echo "Installation de Cockpit..."
sudo dnf install -y cockpit
sudo systemctl enable --now cockpit.socket

# Installation de nginx et certbot
echo ""
echo "Installation de nginx et certbot..."
sudo dnf install -y nginx certbot python3-certbot-nginx

# Création d'un certificat temporaire
echo ""
echo "Création d'un certificat SSL temporaire..."
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx-selfsigned.key \
  -out /etc/nginx/ssl/nginx-selfsigned.crt \
  -subj "/CN=$NIP_DOMAIN" 2>/dev/null

# Configuration nginx
echo ""
echo "Configuration de nginx..."
sudo tee /etc/nginx/conf.d/cockpit.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $NIP_DOMAIN;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    http2 on;
    server_name $NIP_DOMAIN;
    
    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
    
    location / {
        proxy_pass https://localhost:9090;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        gzip off;
    }
}
EOF

# Test et démarrage nginx
echo ""
echo "Démarrage de nginx..."
sudo nginx -t
sudo systemctl enable --now nginx

# Configuration du firewall
echo ""
echo "Configuration du firewall..."
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# Obtention du certificat Let's Encrypt
echo ""
echo "Obtention du certificat Let's Encrypt..."
echo "ATTENTION: Vous devez accepter les conditions de Let's Encrypt"
sleep 2

sudo certbot --nginx -d $NIP_DOMAIN --non-interactive --agree-tos --register-unsafely-without-email || {
    echo ""
    echo "ERREUR: Impossible d'obtenir le certificat Let's Encrypt"
    echo "Le serveur reste accessible avec le certificat auto-signé"
    echo "Vous pouvez réessayer manuellement: sudo certbot --nginx -d $NIP_DOMAIN"
}

# Test final
echo ""
echo "=========================================="
echo "Installation terminée!"
echo "=========================================="
echo "Cockpit est accessible via:"
echo "  https://$NIP_DOMAIN"
echo ""
echo "Les étudiants peuvent se connecter avec leurs comptes Unix"
echo ""
echo "Pour tester: curl -k https://$NIP_DOMAIN"
echo "=========================================="

#!/bin/bash
#
# VM Migration Tool - One Command Installer
# Für bereits existierende Ubuntu VMs
#

set -e

echo "🚀 VM Migration Tool - Quick Install"
echo ""

# Check Ubuntu
if [ ! -f /etc/os-release ]; then
    echo "❌ Kein Ubuntu gefunden"
    exit 1
fi

# Update & Docker
echo "[1/4] Installiere Docker..."
curl -fsSL https://get.docker.com | sh
systemctl start docker
systemctl enable docker

# Docker Compose
echo "[2/4] Installiere Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone Repository
echo "[3/4] Clone Repository..."
cd /opt
git clone https://github.com/thiemostappen-del/vm-migration-tool.git
cd vm-migration-tool

# Setup
echo "[4/4] Konfiguriere & Starte..."
cp .env.example .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$(openssl rand -base64 32)/" .env
sed -i "s/SECRET_KEY=.*/SECRET_KEY=$(openssl rand -base64 48)/" .env

docker-compose build
docker-compose up -d

IP=$(hostname -I | awk '{print $1}')

echo ""
echo "✅ Fertig!"
echo ""
echo "Zugriff: http://$IP:3000"
echo "API: http://$IP:8000/docs"
echo ""

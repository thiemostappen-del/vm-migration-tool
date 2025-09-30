#!/bin/bash
#
# VMware to Proxmox Migration Tool - Automated Installer
# Run this script on a fresh Ubuntu 22.04 VM in Proxmox
#
# Usage: curl -fsSL https://raw.githubusercontent.com/yourrepo/install.sh | bash
#

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VMware → Proxmox Migration Tool Installer          ║${NC}"
echo -e "${BLUE}║   Version 1.0                                         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Bitte als root ausführen: sudo bash install.sh${NC}" 
   exit 1
fi

# Check OS
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Nicht unterstütztes OS${NC}"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    echo -e "${RED}Nur Ubuntu wird unterstützt. Gefunden: $ID${NC}"
    exit 1
fi

echo -e "${GREEN}✓ OS Check passed: Ubuntu $VERSION_ID${NC}"

# Update system
echo -e "${BLUE}[1/8] System-Update...${NC}"
apt-get update -qq
apt-get upgrade -y -qq

# Install dependencies
echo -e "${BLUE}[2/8] Installiere Abhängigkeiten...${NC}"
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    qemu-utils \
    nbdkit \
    openssh-client

echo -e "${GREEN}✓ Abhängigkeiten installiert${NC}"

# Install Docker
echo -e "${BLUE}[3/8] Installiere Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker installiert${NC}"
else
    echo -e "${GREEN}✓ Docker bereits installiert${NC}"
fi

# Install Docker Compose
echo -e "${BLUE}[4/8] Installiere Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose installiert${NC}"
else
    echo -e "${GREEN}✓ Docker Compose bereits installiert${NC}"
fi

# Create application directory
echo -e "${BLUE}[5/8] Erstelle Anwendungsverzeichnis...${NC}"
APP_DIR="/opt/vm-migration-tool"
mkdir -p $APP_DIR
cd $APP_DIR

# Download/Create application files
echo -e "${BLUE}[6/8] Lade Anwendungsdateien herunter...${NC}"

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    container_name: migration-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: migration_tool
      POSTGRES_USER: migration_user
      POSTGRES_PASSWORD: ${DB_PASSWORD:-changeme123}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - migration-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U migration_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: migration-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - migration-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: migration-tool-backend:latest
    container_name: migration-backend
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://migration_user:${DB_PASSWORD:-changeme123}@db:5432/migration_tool
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: ${SECRET_KEY:-change-this-secret-key}
      ENVIRONMENT: production
    volumes:
      - ./logs:/app/logs
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - migration-net
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  celery-worker:
    image: migration-tool-backend:latest
    container_name: migration-celery-worker
    restart: unless-stopped
    command: celery -A app.celery_app worker --loglevel=info --concurrency=2
    environment:
      DATABASE_URL: postgresql://migration_user:${DB_PASSWORD:-changeme123}@db:5432/migration_tool
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: ${SECRET_KEY:-change-this-secret-key}
    volumes:
      - ./logs:/app/logs
    networks:
      - migration-net
    depends_on:
      - redis
      - db

  celery-beat:
    image: migration-tool-backend:latest
    container_name: migration-celery-beat
    restart: unless-stopped
    command: celery -A app.celery_app beat --loglevel=info
    environment:
      DATABASE_URL: postgresql://migration_user:${DB_PASSWORD:-changeme123}@db:5432/migration_tool
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: ${SECRET_KEY:-change-this-secret-key}
    volumes:
      - ./logs:/app/logs
    networks:
      - migration-net
    depends_on:
      - redis
      - db

  frontend:
    image: migration-tool-frontend:latest
    container_name: migration-frontend
    restart: unless-stopped
    ports:
      - "3000:80"
    environment:
      VITE_API_URL: http://localhost:8000
    networks:
      - migration-net
    depends_on:
      - backend

volumes:
  postgres_data:
  redis_data:

networks:
  migration-net:
    driver: bridge
EOF

# Create .env file
cat > .env <<'EOF'
# Database
DB_PASSWORD=SecurePassword123!

# Security
SECRET_KEY=change-this-to-a-random-secret-key-min-32-chars

# Proxmox Configuration (wird über GUI konfiguriert)
# PROXMOX_HOST=
# PROXMOX_USER=
# PROXMOX_PASSWORD=

# VMware Configuration (wird über GUI konfiguriert)
# VMWARE_HOST=
# VMWARE_USER=
# VMWARE_PASSWORD=
EOF

echo -e "${GREEN}✓ Konfigurationsdateien erstellt${NC}"

# Generate secure passwords
echo -e "${BLUE}[7/8] Generiere sichere Passwörter...${NC}"
DB_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 48)

sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" .env

echo -e "${GREEN}✓ Passwörter generiert${NC}"

# Create systemd service for auto-start
echo -e "${BLUE}[8/8] Erstelle Systemd Service...${NC}"
cat > /etc/systemd/system/vm-migration-tool.service <<EOF
[Unit]
Description=VM Migration Tool
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vm-migration-tool.service

echo -e "${GREEN}✓ Systemd Service erstellt${NC}"

# Get IP address
IP_ADDR=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installation erfolgreich abgeschlossen! ✓          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Nächste Schritte:${NC}"
echo ""
echo -e "1. Docker Images bauen/laden:"
echo -e "   ${BLUE}cd $APP_DIR${NC}"
echo -e "   ${BLUE}# Entweder Images bauen:${NC}"
echo -e "   ${BLUE}docker-compose build${NC}"
echo -e "   ${BLUE}# Oder Images laden (wenn bereitgestellt):${NC}"
echo -e "   ${BLUE}docker load < migration-tool-images.tar${NC}"
echo ""
echo -e "2. Anwendung starten:"
echo -e "   ${BLUE}docker-compose up -d${NC}"
echo ""
echo -e "3. Status prüfen:"
echo -e "   ${BLUE}docker-compose ps${NC}"
echo ""
echo -e "4. Logs anzeigen:"
echo -e "   ${BLUE}docker-compose logs -f${NC}"
echo ""
echo -e "5. Web-Interface öffnen:"
echo -e "   ${GREEN}http://$IP_ADDR:3000${NC}"
echo ""
echo -e "${BLUE}Konfiguration:${NC}"
echo -e "   Datei: ${GREEN}$APP_DIR/.env${NC}"
echo ""
echo -e "${BLUE}Service-Verwaltung:${NC}"
echo -e "   ${BLUE}systemctl start vm-migration-tool${NC}  - Starten"
echo -e "   ${BLUE}systemctl stop vm-migration-tool${NC}   - Stoppen"
echo -e "   ${BLUE}systemctl status vm-migration-tool${NC} - Status"
echo ""
echo -e "${RED}WICHTIG: Ändern Sie die Passwörter in $APP_DIR/.env!${NC}"
echo ""

#!/bin/bash
#
# VM Migration Tool - Installation Script (Fixed)
# For existing Ubuntu 22.04+ VMs
#

set -e

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   VM Migration Tool - Installation                    ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo bash install.sh)"
    exit 1
fi

# Check Ubuntu
if [ ! -f /etc/os-release ]; then
    echo "Error: Not an Ubuntu system"
    exit 1
fi

# Install Docker
echo "[1/5] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    echo "  ✓ Docker installed"
else
    echo "  ✓ Docker already installed"
fi

# Install Docker Compose
echo "[2/5] Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "  ✓ Docker Compose installed"
else
    echo "  ✓ Docker Compose already installed"
fi

# Clone repository
echo "[3/5] Cloning repository..."
cd /opt
if [ -d "vm-migration-tool" ]; then
    echo "  Directory exists, pulling latest..."
    cd vm-migration-tool
    git pull
else
    git clone https://github.com/thiemostappen-del/vm-migration-tool.git
    cd vm-migration-tool
fi
echo "  ✓ Repository ready"

# Configure environment
echo "[4/5] Configuring environment..."

# Generate secure passwords
DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
SECRET_KEY=$(openssl rand -base64 48 | tr -d '/+=' | head -c 48)

# Create .env file
cat > .env << EOF
# Database
DB_PASSWORD=${DB_PASSWORD}

# Security
SECRET_KEY=${SECRET_KEY}

# Optional: Default credentials (configure via GUI)
VMWARE_HOST=
VMWARE_USER=
VMWARE_PASSWORD=

PROXMOX_HOST=
PROXMOX_USER=
PROXMOX_PASSWORD=
EOF

echo "  ✓ Environment configured"

# Create logs directory
mkdir -p logs

# Build and start
echo "[5/5] Building and starting containers..."
docker-compose build
docker-compose up -d

echo "  ✓ Containers started"

# Wait for services
echo ""
echo "Waiting for services to start..."
sleep 10

# Get IP
IP=$(hostname -I | awk '{print $1}')

# Check if running
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║   Installation erfolgreich! ✅                        ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    echo "Zugriff:"
    echo "  Frontend:  http://${IP}:3000"
    echo "  API:       http://${IP}:8000/docs"
    echo ""
    echo "Status prüfen:"
    echo "  docker-compose ps"
    echo "  docker-compose logs -f"
    echo ""
    echo "Logs:"
    echo "  /opt/vm-migration-tool/logs/"
    echo ""
else
    echo ""
    echo "⚠️  Container started but may have issues"
    echo "Check logs: docker-compose logs"
fi

#!/bin/bash
#
# VM Migration Tool - Cloud-Init Deployment (Fastest!)
# Vollautomatische Installation ohne manuelle Schritte
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Migration Tool - Cloud-Init Deployment             ║${NC}"
echo -e "${BLUE}║   Vollautomatisch in ~5 Minuten fertig! ⚡            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
VM_ID=${1:-200}
VM_NAME="migration-tool"
VM_CORES=4
VM_MEMORY=8192
VM_DISK_SIZE="100G"
VM_STORAGE="local-lvm"
VM_BRIDGE="vmbr0"
TEMPLATE_STORAGE="local"

# SSH Key
SSH_KEY="${2:-}"
if [ -z "$SSH_KEY" ]; then
    if [ -f ~/.ssh/id_rsa.pub ]; then
        SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
    else
        echo -e "${RED}Kein SSH-Key gefunden. Bitte angeben oder generieren:${NC}"
        echo "  ssh-keygen -t rsa -b 4096"
        exit 1
    fi
fi

# Ubuntu Cloud Image URL
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
CLOUD_IMAGE_NAME="ubuntu-22.04-cloudimg-amd64.img"
CLOUD_IMAGE_PATH="/var/lib/vz/template/iso/$CLOUD_IMAGE_NAME"

echo -e "${BLUE}[1/6] Lade Ubuntu Cloud Image...${NC}"
if [ ! -f "$CLOUD_IMAGE_PATH" ]; then
    wget -q --show-progress -O "$CLOUD_IMAGE_PATH" "$CLOUD_IMAGE_URL"
    echo -e "${GREEN}✓ Image heruntergeladen${NC}"
else
    echo -e "${GREEN}✓ Image bereits vorhanden${NC}"
fi

echo -e "${BLUE}[2/6] Erstelle VM...${NC}"
qm create $VM_ID \
    --name $VM_NAME \
    --memory $VM_MEMORY \
    --cores $VM_CORES \
    --net0 virtio,bridge=$VM_BRIDGE \
    --ostype l26 \
    --agent 1

echo -e "${GREEN}✓ VM erstellt${NC}"

echo -e "${BLUE}[3/6] Importiere Cloud Image...${NC}"
qm importdisk $VM_ID "$CLOUD_IMAGE_PATH" $VM_STORAGE

echo -e "${GREEN}✓ Disk importiert${NC}"

echo -e "${BLUE}[4/6] Konfiguriere VM...${NC}"
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $VM_STORAGE:vm-$VM_ID-disk-0
qm set $VM_ID --boot order=scsi0
qm set $VM_ID --ide2 $VM_STORAGE:cloudinit
qm set $VM_ID --serial0 socket --vga serial0

# Resize disk
qm resize $VM_ID scsi0 $VM_DISK_SIZE

echo -e "${GREEN}✓ VM konfiguriert${NC}"

echo -e "${BLUE}[5/6] Setze Cloud-Init Parameter...${NC}"

# Cloud-Init User-Data
cat > /tmp/migration-tool-cloud-init.yml <<EOF
#cloud-config
hostname: migration-tool
manage_etc_hosts: true

users:
  - name: admin
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - $SSH_KEY

packages:
  - qemu-utils
  - curl
  - git

runcmd:
  - echo "Starting Migration Tool installation..." > /var/log/migration-tool-install.log
  - curl -fsSL https://raw.githubusercontent.com/yourrepo/install.sh -o /tmp/install.sh 2>> /var/log/migration-tool-install.log
  - bash /tmp/install.sh >> /var/log/migration-tool-install.log 2>&1
  - systemctl enable vm-migration-tool >> /var/log/migration-tool-install.log 2>&1
  - systemctl start vm-migration-tool >> /var/log/migration-tool-install.log 2>&1
  - echo "Installation complete!" >> /var/log/migration-tool-install.log

final_message: "Migration Tool VM is ready! Duration: \$UPTIME seconds"
EOF

# Set Cloud-Init config
qm set $VM_ID --cicustom "user=local:snippets/migration-tool-user.yml"

# Copy cloud-init to snippets
mkdir -p /var/lib/vz/snippets
cp /tmp/migration-tool-cloud-init.yml /var/lib/vz/snippets/migration-tool-user.yml
rm /tmp/migration-tool-cloud-init.yml

# Set IP config (DHCP)
qm set $VM_ID --ipconfig0 ip=dhcp

echo -e "${GREEN}✓ Cloud-Init konfiguriert${NC}"

echo -e "${BLUE}[6/6] Starte VM...${NC}"
qm start $VM_ID

echo -e "${GREEN}✓ VM gestartet${NC}"

# Wait for IP
echo -e "${BLUE}Warte auf IP-Adresse...${NC}"
for i in {1..30}; do
    sleep 2
    VM_IP=$(qm guest cmd $VM_ID network-get-interfaces 2>/dev/null | grep -oP '(?<="ip-address":")[\d.]+' | grep -v "127.0.0.1" | head -1 || echo "")
    if [ -n "$VM_IP" ]; then
        break
    fi
    echo -n "."
done
echo ""

if [ -z "$VM_IP" ]; then
    VM_IP="<wird automatisch per DHCP bezogen>"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   VM wird automatisch installiert! ⚡                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}VM Details:${NC}"
echo "  VM ID:      $VM_ID"
echo "  Name:       $VM_NAME"
echo "  IP:         $VM_IP"
echo "  Status:     Installing..."
echo ""
echo -e "${BLUE}Die Installation läuft im Hintergrund (~5 Minuten).${NC}"
echo ""
echo "Installation prüfen:"
echo "  ${BLUE}ssh admin@$VM_IP${NC}"
echo "  ${BLUE}tail -f /var/log/migration-tool-install.log${NC}"
echo ""
echo "Nach Abschluss verfügbar unter:"
echo "  ${GREEN}http://$VM_IP:3000${NC}"
echo ""
echo "Status prüfen:"
echo "  ${BLUE}ssh admin@$VM_IP 'systemctl status vm-migration-tool'${NC}"
echo ""
echo -e "${GREEN}Fertig! 🎉${NC}"

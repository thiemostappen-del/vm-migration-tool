#!/bin/bash
#
# Automatische VM-Erstellung für Migration Tool
# Direkt auf dem Proxmox-Host ausführen
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Migration Tool VM - Automatische Erstellung        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running on Proxmox
if [ ! -f /etc/pve/local/pve-ssl.pem ]; then
    echo -e "${RED}Dieses Script muss auf einem Proxmox-Host ausgeführt werden!${NC}"
    exit 1
fi

# Configuration
VM_ID=${1:-200}  # Default VM ID 200
VM_NAME="migration-tool"
VM_CORES=4
VM_MEMORY=8192  # 8 GB
VM_DISK_SIZE="100G"
VM_STORAGE="local-lvm"  # Anpassen falls nötig
VM_BRIDGE="vmbr0"
ISO_STORAGE="local"
ISO_FILE="ubuntu-22.04.3-live-server-amd64.iso"

echo -e "${BLUE}VM Konfiguration:${NC}"
echo "  VM ID:      $VM_ID"
echo "  Name:       $VM_NAME"
echo "  CPU:        $VM_CORES Cores"
echo "  RAM:        $((VM_MEMORY/1024)) GB"
echo "  Disk:       $VM_DISK_SIZE"
echo "  Storage:    $VM_STORAGE"
echo "  Network:    $VM_BRIDGE"
echo ""

read -p "Fortfahren? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Check if VM ID already exists
if qm status $VM_ID &>/dev/null; then
    echo -e "${RED}VM ID $VM_ID existiert bereits!${NC}"
    exit 1
fi

# Check if ISO exists
if [ ! -f "/var/lib/vz/template/iso/$ISO_FILE" ]; then
    echo -e "${RED}Ubuntu ISO nicht gefunden: $ISO_FILE${NC}"
    echo -e "${BLUE}Bitte ISO herunterladen:${NC}"
    echo "  cd /var/lib/vz/template/iso"
    echo "  wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"
    exit 1
fi

echo -e "${BLUE}[1/5] Erstelle VM...${NC}"
qm create $VM_ID \
    --name $VM_NAME \
    --memory $VM_MEMORY \
    --cores $VM_CORES \
    --net0 virtio,bridge=$VM_BRIDGE \
    --ide2 $ISO_STORAGE:iso/$ISO_FILE,media=cdrom \
    --boot order=ide2 \
    --ostype l26 \
    --agent 1

echo -e "${GREEN}✓ VM erstellt${NC}"

echo -e "${BLUE}[2/5] Erstelle Disk...${NC}"
qm set $VM_ID --scsi0 $VM_STORAGE:$VM_DISK_SIZE

echo -e "${GREEN}✓ Disk erstellt${NC}"

echo -e "${BLUE}[3/5] Setze Boot-Optionen...${NC}"
qm set $VM_ID --boot order=scsi0

echo -e "${GREEN}✓ Boot-Optionen gesetzt${NC}"

echo -e "${BLUE}[4/5] Starte VM...${NC}"
qm start $VM_ID

echo -e "${GREEN}✓ VM gestartet${NC}"

# Get VM IP (nach Installation)
echo -e "${BLUE}[5/5] Warte auf VM-Start...${NC}"
sleep 10

VM_IP=$(qm guest cmd $VM_ID network-get-interfaces | grep -oP '(?<="ip-address":")[\d.]+' | grep -v "127.0.0.1" | head -1 || echo "N/A")

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   VM erfolgreich erstellt! ✓                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}VM Details:${NC}"
echo "  VM ID:   $VM_ID"
echo "  Name:    $VM_NAME"
echo "  Status:  Running"
echo ""
echo -e "${BLUE}Nächste Schritte:${NC}"
echo ""
echo "1. Ubuntu Server installieren:"
echo "   - Console öffnen: Proxmox UI → VM $VM_ID → Console"
echo "   - Ubuntu Installation durchführen"
echo "   - SSH-Server aktivieren"
echo "   - Hostname: migration-tool"
echo ""
echo "2. Nach Ubuntu-Installation:"
echo "   ${BLUE}ssh ubuntu@<vm-ip>${NC}"
echo "   ${BLUE}curl -fsSL <installer-url> | sudo bash${NC}"
echo ""
echo "3. Oder Cloud-Init-Image verwenden (schneller):"
echo "   ${BLUE}bash create-vm-cloudinit.sh $VM_ID${NC}"
echo ""

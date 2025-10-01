#!/bin/bash
#
# VM Migration Tool - Automated VM Creation with Cloud-Init
# Creates and configures a Ubuntu VM on Proxmox with VGA console
#

set -e

# Configuration
VM_ID=${1:-200}
VM_NAME="migration-tool"
VM_CORES=4
VM_MEMORY=8192
VM_DISK_SIZE=100G
STORAGE="local-lvm"
# Optional second argument allows overriding the bridge (default vmbr0)
BRIDGE="${2:-vmbr0}"
# Optional third argument allows specifying a VLAN tag
VLAN_TAG="${3:-}"
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
CLOUD_IMAGE="/tmp/jammy-cloudimg.img"

wait_for_ip() {
    local attempts=${1:-60}
    IP=""
    for ((i=1; i<=attempts; i++)); do
        IP=$(qm guest cmd $VM_ID network-get-interfaces 2>/dev/null | \
            grep -oP '(?<="ip-address":")[\d.]+' | grep -v "127.0.0.1" | head -1)
        if [ -n "$IP" ]; then
            return 0
        fi
        echo -n "."
        sleep 2
    done
    return 1
}

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   VM Migration Tool - Automated Installation         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "VM Configuration:"
echo "  VM ID:      $VM_ID"
echo "  Name:       $VM_NAME"
echo "  Cores:      $VM_CORES"
echo "  Memory:     $VM_MEMORY MB"
echo "  Disk:       $VM_DISK_SIZE"
echo "  Network:    $BRIDGE"
if [ -n "$VLAN_TAG" ]; then
    echo "  VLAN Tag:   $VLAN_TAG"
else
    echo "  VLAN Tag:   <none>"
fi

MAC_ADDRESS=""

# Validate network bridge
if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
    echo "Error: Network bridge '$BRIDGE' not found on this host."
    echo "Available bridges:"
    ip -o link show | awk -F': ' '/vmbr/ {print "  - "$2}'
    exit 1
fi

# Validate VLAN tag when provided
if [ -n "$VLAN_TAG" ]; then
    if ! [[ $VLAN_TAG =~ ^[0-9]+$ ]] || [ "$VLAN_TAG" -lt 1 ] || [ "$VLAN_TAG" -gt 4094 ]; then
        echo "Error: VLAN tag must be a number between 1 and 4094."
        exit 1
    fi
fi
echo ""

# Check if VM exists
if qm status $VM_ID &>/dev/null; then
    echo "Error: VM $VM_ID already exists!"
    echo "Delete it first with: qm destroy $VM_ID"
    exit 1
fi

# Download cloud image
echo "[1/6] Downloading Ubuntu Cloud Image..."
if [ ! -f "$CLOUD_IMAGE" ]; then
    wget -q --show-progress -O "$CLOUD_IMAGE" "$CLOUD_IMAGE_URL"
fi
echo "✓ Image downloaded"

# Build network adapter configuration string used during creation
NET_OPTS_CREATE="virtio,bridge=$BRIDGE"
if [ -n "$VLAN_TAG" ]; then
    NET_OPTS_CREATE+=",tag=$VLAN_TAG"
fi

# Create VM
echo "[2/6] Creating VM..."
qm create $VM_ID \
    --name "$VM_NAME" \
    --cores $VM_CORES \
    --memory $VM_MEMORY \
    --net0 "$NET_OPTS_CREATE" \
    --ostype l26

# Read back the generated MAC address so subsequent updates do not replace it
NET_CONFIG=$(qm config $VM_ID | awk -F': ' '/^net0: / {print $2}')
MAC_ADDRESS=$(sed -n 's/.*macaddr=\([^,]*\).*/\1/p' <<<"$NET_CONFIG")
if [ -z "$MAC_ADDRESS" ]; then
    MAC_ADDRESS=$(sed -n 's/^virtio=\([^,]*\).*/\1/p' <<<"$NET_CONFIG")
fi
if [ -z "$MAC_ADDRESS" ]; then
    # Generate a stable qemu OUI based MAC as fallback to avoid leaving the
    # adapter without a hardware address
    read -r -a RAND_BYTES < <(od -An -N4 -t u1 /dev/urandom)
    if [ "${#RAND_BYTES[@]}" -lt 4 ]; then
        echo "Error: Unable to generate a fallback MAC address."
        exit 1
    fi
    MAC_ADDRESS=$(printf '52:54:%02x:%02x:%02x:%02x' "${RAND_BYTES[@]}")
fi

# Rebuild the definitive network configuration string preserving the MAC using
# the virtio property so Proxmox keeps the generated address together with the
# bridge and optional VLAN assignments.
NET_OPTS="virtio=$MAC_ADDRESS,bridge=$BRIDGE"
if [ -n "$VLAN_TAG" ]; then
    NET_OPTS+=",tag=$VLAN_TAG"
fi

# Ensure the network device is correctly attached (some Proxmox versions ignore
# the flag during creation when importing disks afterwards)
qm set $VM_ID --net0 "$NET_OPTS" >/dev/null

# Verify network configuration so the VM actually receives a lease later on
NET_CONFIG=$(qm config $VM_ID | awk -F': ' '/^net0: / {print $2}')
if [[ -z $NET_CONFIG ]]; then
    echo "Error: Failed to configure network adapter (net0 missing)."
    exit 1
fi

if [[ $NET_CONFIG != *"bridge=$BRIDGE"* ]]; then
    echo "Network adapter bridge mismatch detected, retrying configuration..."
    qm set $VM_ID --net0 "$NET_OPTS" >/dev/null
    NET_CONFIG=$(qm config $VM_ID | awk -F': ' '/^net0: / {print $2}')
    if [[ $NET_CONFIG != *"bridge=$BRIDGE"* ]]; then
        echo "Error: Unable to attach network adapter to bridge '$BRIDGE'."
        exit 1
    fi
fi

if [ -n "$VLAN_TAG" ] && [[ $NET_CONFIG != *"tag=$VLAN_TAG"* ]]; then
    echo "Network adapter VLAN tag mismatch detected, retrying configuration..."
    qm set $VM_ID --net0 "$NET_OPTS" >/dev/null
    NET_CONFIG=$(qm config $VM_ID | awk -F': ' '/^net0: / {print $2}')
    if [[ $NET_CONFIG != *"tag=$VLAN_TAG"* ]]; then
        echo "Error: Unable to set VLAN tag '$VLAN_TAG' on network adapter."
        exit 1
    fi
fi

if [[ $NET_CONFIG == *"virtio=$MAC_ADDRESS"* ]]; then
    EFFECTIVE_MAC="$MAC_ADDRESS"
else
    EFFECTIVE_MAC=$(sed -n 's/^virtio=\([^,]*\).*/\1/p' <<<"$NET_CONFIG")
    if [ -z "$EFFECTIVE_MAC" ]; then
        EFFECTIVE_MAC=$(sed -n 's/.*macaddr=\([^,]*\).*/\1/p' <<<"$NET_CONFIG")
    fi
fi

echo "  → Netzwerkadapter: ${EFFECTIVE_MAC:-$MAC_ADDRESS} → $BRIDGE${VLAN_TAG:+ (VLAN $VLAN_TAG)}"

# Enable the QEMU guest agent so Proxmox can retrieve network information once
# cloud-init has finished bootstrapping the VM
qm set $VM_ID --agent enabled=1 >/dev/null
echo "✓ VM created"

# Import disk
echo "[3/6] Importing disk..."
qm importdisk $VM_ID "$CLOUD_IMAGE" $STORAGE --format qcow2 > /dev/null 2>&1
echo "✓ Disk imported"

# Configure VM
echo "[4/6] Configuring VM..."
qm set $VM_ID \
    --scsi0 ${STORAGE}:vm-${VM_ID}-disk-0 \
    --scsihw virtio-scsi-pci \
    --boot order=scsi0 \
    --ide2 ${STORAGE}:cloudinit \
    --vga std \
    --serial0 socket

# Resize disk
qm disk resize $VM_ID scsi0 $VM_DISK_SIZE > /dev/null 2>&1
echo "✓ VM configured with VGA console"

# Create cloud-init user-data
echo "[5/6] Setting Cloud-Init parameters..."
mkdir -p /var/lib/vz/snippets

cat > /var/lib/vz/snippets/migration-tool-user.yml << 'EOF'
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... # Add your key here
  - name: tcedv
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: sudo,docker
    lock_passwd: false
    passwd: $6$rounds=4096$saltsalt$hashedpassword # Change this!

disable_root: false
ssh_pwauth: true
chpasswd:
  expire: False
  list: |
    root:password

package_update: true
package_upgrade: true
packages:
  - curl
  - git
  - docker.io
  - docker-compose
  - qemu-guest-agent

runcmd:
  - systemctl start docker
  - systemctl enable docker
  - systemctl enable --now qemu-guest-agent
  - usermod -aG docker tcedv
  - |
    cat > /tmp/install-migration-tool.sh << 'INSTALL_EOF'
    #!/bin/bash
    set -e
    exec > /var/log/migration-tool-install.log 2>&1
    
    echo "Starting Migration Tool installation..."
    
    cd /opt
    git clone https://github.com/thiemostappen-del/vm-migration-tool.git
    cd vm-migration-tool
    
    # Create .env with secure passwords
    cat > .env << 'ENV_EOF'
DB_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 48)
VMWARE_HOST=
VMWARE_USER=
VMWARE_PASSWORD=
PROXMOX_HOST=
PROXMOX_USER=
PROXMOX_PASSWORD=
ENV_EOF
    
    # Generate actual passwords
    DB_PASS=$(openssl rand -base64 32)
    SECRET=$(openssl rand -base64 48)
    
    cat > .env << ENV_EOF2
DB_PASSWORD=$DB_PASS
SECRET_KEY=$SECRET
VMWARE_HOST=
VMWARE_USER=
VMWARE_PASSWORD=
PROXMOX_HOST=
PROXMOX_USER=
PROXMOX_PASSWORD=
ENV_EOF2
    
    # Build and start
    docker-compose build
    docker-compose up -d
    
    echo "Migration Tool installation complete!"
    echo "Access at: http://$(hostname -I | awk '{print $1}'):3000"
    INSTALL_EOF
  - chmod +x /tmp/install-migration-tool.sh
  - nohup /tmp/install-migration-tool.sh &

final_message: "Migration Tool VM is ready. Installation running in background (~5 minutes)"
EOF

qm set $VM_ID --cicustom "user=local:snippets/migration-tool-user.yml"
qm set $VM_ID --ipconfig0 ip=dhcp
echo "✓ Cloud-Init configured"

# Start VM
echo "[6/6] Starting VM..."
qm start $VM_ID
echo "✓ VM started"

# Wait for IP (with timeout)
echo ""
echo "Waiting for IP address..."
if ! wait_for_ip 60; then
    echo ""
    echo "Keine IP-Adresse per DHCP erhalten."
    read -rp "Statische IP (z.B. 192.168.1.50/24) eingeben oder leer lassen, um zu überspringen: " MANUAL_IP
    if [ -n "$MANUAL_IP" ]; then
        read -rp "Gateway (z.B. 192.168.1.1) eingeben oder leer lassen, falls nicht benötigt: " MANUAL_GW
        echo "Setze statische IP-Konfiguration..."
        if [ -n "$MANUAL_GW" ]; then
            qm set $VM_ID --ipconfig0 ip=${MANUAL_IP},gw=${MANUAL_GW} >/dev/null
        else
            qm set $VM_ID --ipconfig0 ip=${MANUAL_IP} >/dev/null
        fi
        echo "Starte die VM neu, um die Netzwerkkonfiguration zu übernehmen..."
        qm reboot $VM_ID >/dev/null
        echo "Warte auf IP-Adresse..."
        if ! wait_for_ip 60; then
            echo "Keine IP-Adresse über den Gast-Agent erhalten. Bitte IP in Proxmox prüfen."
        fi
    fi
fi
echo ""

if [ -z "$IP" ] && [ -n "${MANUAL_IP:-}" ]; then
    IP="${MANUAL_IP%%/*}"
fi

# Final message
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   VM wird automatisch installiert! ⚡                  ║"
echo "╚═══════════════════════════════════════════════════════╝"

if [ -n "$IP" ]; then
    echo "VM Details:"
    echo "  VM ID:      $VM_ID"
    echo "  Name:       $VM_NAME"
    echo "  IP:         $IP"
    echo "  Status:     Installing..."
    echo ""
    echo "Installation läuft im Hintergrund (~5 Minuten)."
    echo ""
    echo "Installation prüfen:"
    echo "  ssh tcedv@$IP"
    echo "  tail -f /var/log/migration-tool-install.log"
    echo ""
    echo "Nach Abschluss verfügbar unter:"
    echo "  http://$IP:3000"
    echo ""
    echo "Console öffnen (mit VGA):"
    echo "  Proxmox UI → VM $VM_ID → Console"
else
    echo "VM Details:"
    echo "  VM ID:      $VM_ID"
    echo "  Name:       $VM_NAME"
    echo "  IP:         <in Proxmox UI prüfen>"
    echo "  Status:     Installing..."
    echo ""
    echo "IP-Adresse in Proxmox UI prüfen:"
    echo "  VM $VM_ID → Summary → IPs"
    echo ""
    echo "Oder Console öffnen (mit VGA):"
    echo "  Proxmox UI → VM $VM_ID → Console"
    echo "  Login: tcedv"
    echo "  Dann: hostname -I"
fi

echo ""
echo "Standard-Zugangsdaten (bitte nach dem ersten Login ändern):"
echo "  root / password"
echo ""
echo "Status prüfen:"
echo "  qm status $VM_ID"
echo "  docker-compose ps (in der VM)"
echo ""
echo "Fertig! 🎉"

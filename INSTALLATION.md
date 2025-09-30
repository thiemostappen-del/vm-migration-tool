# VMware → Proxmox Migration Tool
## Quick Installation Guide

## Variante 1: Automatische Installation (Empfohlen) ⚡

### Schritt 1: VM in Proxmox erstellen
```
Name: migration-tool
OS: Ubuntu 22.04 Server
CPU: 4 Cores
RAM: 8 GB
Disk: 100 GB
Network: Gleiche Bridge wie Hosts
```

### Schritt 2: Ubuntu installieren
- Minimale Installation wählen
- SSH-Server aktivieren
- Benutzer erstellen (z.B. `admin`)

### Schritt 3: Installation ausführen
```bash
# SSH zur VM verbinden
ssh admin@<vm-ip>

# Installation starten (als root)
sudo su -
curl -fsSL https://raw.githubusercontent.com/yourrepo/install.sh -o install.sh
bash install.sh
```

### Schritt 4: Docker Images laden
```bash
cd /opt/vm-migration-tool

# Option A: Images bauen (wenn Source-Code vorhanden)
docker-compose build

# Option B: Images laden (wenn bereitgestellt)
docker load < migration-tool-images.tar
```

### Schritt 5: Starten
```bash
docker-compose up -d
```

### Schritt 6: Zugriff
Browser öffnen: `http://<vm-ip>:3000`

---

## Variante 2: Manuelle Installation

### 1. System vorbereiten
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl docker.io docker-compose qemu-utils
sudo systemctl enable docker
sudo systemctl start docker
```

### 2. Anwendung installieren
```bash
# Verzeichnis erstellen
sudo mkdir -p /opt/vm-migration-tool
cd /opt/vm-migration-tool

# Repository clonen
git clone https://github.com/yourrepo/vm-migration-tool.git .

# Konfiguration anpassen
cp .env.example .env
nano .env  # Passwörter ändern
```

### 3. Starten
```bash
docker-compose up -d
```

---

## Variante 3: Proxmox VM-Template (Fastest) 🚀

### Template erstellen (einmalig)
```bash
# Auf Proxmox-Host ausführen
bash create-vm-template.sh
```

### Template nutzen (für jede neue Installation)
1. Im Proxmox Web-UI: Template `migration-tool-template` auswählen
2. "Clone" → Full Clone
3. VM starten
4. Via SSH verbinden
5. `systemctl start vm-migration-tool`
6. Fertig! 🎉

---

## Troubleshooting

### Ports überprüfen
```bash
netstat -tulpn | grep -E '3000|8000'
```

### Logs anzeigen
```bash
cd /opt/vm-migration-tool
docker-compose logs -f
```

### Services neustarten
```bash
docker-compose restart
```

### Firewall (falls aktiv)
```bash
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp
```

---

## Deinstallation

```bash
cd /opt/vm-migration-tool
docker-compose down -v
sudo rm -rf /opt/vm-migration-tool
sudo systemctl disable vm-migration-tool
sudo rm /etc/systemd/system/vm-migration-tool.service
```

---

## Konfiguration nach Installation

### 1. .env-Datei anpassen
```bash
cd /opt/vm-migration-tool
nano .env
```

### 2. Wichtige Einstellungen
```env
# Sichere Passwörter setzen
DB_PASSWORD=<sicheres-passwort>
SECRET_KEY=<langer-zufälliger-schlüssel>

# Optional: Standard-Credentials (können auch über GUI gesetzt werden)
DEFAULT_PROXMOX_HOST=proxmox.local
DEFAULT_VMWARE_HOST=vcenter.local
```

### 3. Neustart nach Änderungen
```bash
docker-compose restart
```

---

## Support

Logs: `/opt/vm-migration-tool/logs/`
Config: `/opt/vm-migration-tool/.env`
Status: `systemctl status vm-migration-tool`

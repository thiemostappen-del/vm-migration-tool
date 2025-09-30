# VMware → Proxmox Migration Tool
## Installation auf Proxmox

Drei Installationsmethoden verfügbar - von **vollautomatisch** bis **manuell**.

---

## ⚡ Methode 1: Cloud-Init (Empfohlen - 5 Minuten)

**Vollautomatisch - keine manuelle Installation nötig!**

```bash
# Auf Proxmox-Host ausführen:
curl -fsSL https://raw.githubusercontent.com/yourrepo/create-vm-cloudinit.sh -o /tmp/deploy.sh
bash /tmp/deploy.sh 200

# Nach 5 Minuten fertig!
# Zugriff: http://<vm-ip>:3000
```

**Was passiert automatisch:**
- ✅ VM wird erstellt
- ✅ Ubuntu 22.04 installiert
- ✅ Docker installiert
- ✅ Migration Tool installiert
- ✅ Service gestartet

---

## 🚀 Methode 2: Manuelle VM + Auto-Install (10 Minuten)

**Schritt 1:** VM in Proxmox erstellen
```bash
# Auf Proxmox-Host:
bash create-vm.sh 200
```

**Schritt 2:** Ubuntu installieren (via Console)
- Minimale Installation
- SSH aktivieren
- Benutzer: `admin`

**Schritt 3:** Tool installieren
```bash
# SSH zur VM:
ssh admin@<vm-ip>

# Installation:
sudo su -
curl -fsSL https://raw.githubusercontent.com/yourrepo/install.sh | bash
```

---

## 🔧 Methode 3: Komplett Manuell (30 Minuten)

Siehe [INSTALLATION.md](INSTALLATION.md) für Details.

```bash
# 1. VM erstellen (Proxmox UI oder CLI)
# 2. Ubuntu 22.04 installieren
# 3. Manuelle Installation:

sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git qemu-utils

sudo mkdir -p /opt/vm-migration-tool
cd /opt/vm-migration-tool

# Repository clonen
git clone <repo-url> .

# Starten
docker-compose up -d
```

---

## 📋 Systemanforderungen

| Komponente | Minimum | Empfohlen |
|------------|---------|-----------|
| CPU        | 2 Cores | 4 Cores   |
| RAM        | 4 GB    | 8 GB      |
| Disk       | 50 GB   | 100 GB    |
| OS         | Ubuntu 20.04 | Ubuntu 22.04 |

---

## 🎯 Nach der Installation

### Zugriff
- **Web-UI:** `http://<vm-ip>:3000`
- **API:** `http://<vm-ip>:8000/docs`

### Erste Schritte
1. Browser öffnen → `http://<vm-ip>:3000`
2. VMware-Verbindung konfigurieren
3. Proxmox-Verbindung konfigurieren
4. Erste VM migrieren!

### Management
```bash
# Status prüfen
systemctl status vm-migration-tool

# Logs anzeigen
cd /opt/vm-migration-tool
docker-compose logs -f

# Neustart
systemctl restart vm-migration-tool

# Stoppen
systemctl stop vm-migration-tool
```

---

## 📊 Service-Übersicht

Nach Installation laufen folgende Services:

| Service | Port | Beschreibung |
|---------|------|--------------|
| Frontend | 3000 | Web-UI |
| Backend | 8000 | REST API |
| PostgreSQL | 5432 | Datenbank (intern) |
| Redis | 6379 | Message Queue (intern) |

---

## 🔐 Sicherheit

### Passwörter ändern
```bash
cd /opt/vm-migration-tool
nano .env

# Ändern:
DB_PASSWORD=<sicheres-passwort>
SECRET_KEY=<langer-key>
```

### Firewall
```bash
# Falls UFW aktiv:
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp
```

### HTTPS (Optional)
```bash
# Nginx Reverse Proxy mit Let's Encrypt
sudo apt install -y nginx certbot python3-certbot-nginx
# Konfiguration siehe docs/nginx-ssl.md
```

---

## 🆘 Troubleshooting

### VM startet nicht
```bash
# Status prüfen
systemctl status vm-migration-tool

# Logs
journalctl -u vm-migration-tool -f
```

### Docker-Probleme
```bash
# Container-Status
docker-compose ps

# Logs
docker-compose logs -f backend
docker-compose logs -f celery-worker

# Neustart
docker-compose restart
```

### Netzwerk-Probleme
```bash
# Ports prüfen
netstat -tulpn | grep -E '3000|8000'

# Docker-Netzwerk prüfen
docker network inspect vm-migration-tool_migration-net
```

### Komplett neu starten
```bash
cd /opt/vm-migration-tool
docker-compose down -v
docker-compose up -d
```

---

## 📦 Updates

```bash
cd /opt/vm-migration-tool

# Code aktualisieren
git pull

# Images neu bauen
docker-compose build

# Neustart
docker-compose up -d
```

---

## 🗑️ Deinstallation

```bash
# Services stoppen
systemctl stop vm-migration-tool
systemctl disable vm-migration-tool

# Dateien löschen
cd /opt/vm-migration-tool
docker-compose down -v
cd ~
sudo rm -rf /opt/vm-migration-tool

# Systemd Service entfernen
sudo rm /etc/systemd/system/vm-migration-tool.service
sudo systemctl daemon-reload
```

---

## 📚 Weitere Dokumentation

- [Installation Details](INSTALLATION.md)
- [API Dokumentation](http://<vm-ip>:8000/docs)
- [Architektur](ARCHITECTURE.md)
- [FAQ](FAQ.md)

---

## 🎬 Quick Start Video

[Link zu Video-Tutorial einfügen]

---

## 💬 Support

- Issues: GitHub Issues
- Docs: [Dokumentation-Link]
- Email: support@example.com

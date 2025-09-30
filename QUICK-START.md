# 🚀 VMware → Proxmox Migration Tool
## QUICK START - Einfache Installation

---

## ⚡ SCHNELLSTE METHODE (5 Minuten)

### Auf Proxmox-Host ausführen:

```bash
# Script herunterladen
wget https://raw.githubusercontent.com/yourrepo/create-vm-cloudinit.sh

# Ausführen (VM ID 200)
bash create-vm-cloudinit.sh 200

# Nach 5 Minuten fertig!
# Zugriff: http://<vm-ip>:3000
```

**Fertig!** Keine weiteren Schritte nötig ✅

---

## 📋 ALTERNATIVE: Schritt-für-Schritt

### Schritt 1: VM erstellen
```bash
# Auf Proxmox-Host:
bash create-vm.sh 200
```

### Schritt 2: Ubuntu installieren
- Console öffnen (Proxmox UI)
- Ubuntu Server 22.04 installieren
- SSH aktivieren

### Schritt 3: Tool installieren
```bash
# SSH zur VM:
ssh admin@<vm-ip>

# Als root:
sudo su -
curl -fsSL https://raw.githubusercontent.com/yourrepo/install.sh | bash

# Starten:
cd /opt/vm-migration-tool
docker-compose up -d
```

---

## 🎯 Nach Installation

### Web-Interface öffnen:
```
http://<vm-ip>:3000
```

### Status prüfen:
```bash
systemctl status vm-migration-tool
```

### Logs anzeigen:
```bash
cd /opt/vm-migration-tool
docker-compose logs -f
```

---

## 📦 Dateien in diesem Paket

| Datei | Zweck |
|-------|-------|
| `create-vm-cloudinit.sh` | Vollautomatische Installation ⚡ |
| `create-vm.sh` | VM-Erstellung auf Proxmox |
| `install.sh` | Tool-Installation in Ubuntu |
| `README.md` | Vollständige Dokumentation |
| `INSTALLATION.md` | Detaillierte Anleitung |

---

## ⚙️ System-Anforderungen

**VM-Spezifikationen:**
- CPU: 4 Cores
- RAM: 8 GB
- Disk: 100 GB
- OS: Ubuntu 22.04 Server

**Netzwerk:**
- Zugriff auf VMware-Host
- Zugriff auf Proxmox-Host
- Internet (für Downloads)

---

## 🔧 Verwaltung

### Service starten:
```bash
systemctl start vm-migration-tool
```

### Service stoppen:
```bash
systemctl stop vm-migration-tool
```

### Neustart:
```bash
systemctl restart vm-migration-tool
```

### Konfiguration ändern:
```bash
nano /opt/vm-migration-tool/.env
docker-compose restart
```

---

## 🆘 Probleme?

### Service läuft nicht:
```bash
systemctl status vm-migration-tool
journalctl -u vm-migration-tool -f
```

### Docker-Container prüfen:
```bash
cd /opt/vm-migration-tool
docker-compose ps
docker-compose logs
```

### Neustart erzwingen:
```bash
cd /opt/vm-migration-tool
docker-compose down -v
docker-compose up -d
```

---

## 📞 Support

Siehe README.md für vollständige Dokumentation.

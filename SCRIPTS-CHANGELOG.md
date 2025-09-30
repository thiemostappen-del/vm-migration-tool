# Installation Scripts - Alle Änderungen

## Zusammenfassung der Script-Fixes

### 1. create-vm-cloudinit.sh
**Probleme behoben:**
- ✅ VGA Console statt Serial (`--vga std` statt `--vga serial0`)
- ✅ .env wird mit sicheren Passwörtern erstellt
- ✅ Bessere Fehlerbehandlung beim IP-Lookup
- ✅ Console-Hinweise für Troubleshooting

**Wichtigste Änderung (Zeile ~52):**
```bash
# Alt:
qm set $VM_ID --serial0 socket --vga serial0

# Neu:
qm set $VM_ID --vga std --serial0 socket
```

---

### 2. install.sh
**Probleme behoben:**
- ✅ .env wird korrekt erstellt (nicht .env.example)
- ✅ Sichere Passwort-Generierung
- ✅ Bessere Status-Checks
- ✅ Klarere Ausgabe

**Wichtigste Änderung:**
```bash
# Sichere Passwort-Generierung
DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
SECRET_KEY=$(openssl rand -base64 48 | tr -d '/+=' | head -c 48)
```

---

### 3. quick-install.sh
**Bereits erstellt, aber sollte auch updated werden**

---

## Was auf GitHub ersetzen:

### Direkt ersetzen:
1. `create-vm-cloudinit.sh` → Mit [create-vm-cloudinit-fixed.sh]
2. `install.sh` → Mit [install-fixed.sh]

### Zusätzlich hinzufügen:
3. `create-vm.sh` - Sollte auch VGA bekommen falls vorhanden

---

## Test nach Update:

```bash
# Auf Proxmox:
# 1. Script herunterladen
wget https://raw.githubusercontent.com/thiemostappen-del/vm-migration-tool/main/create-vm-cloudinit.sh

# 2. Ausführen
bash create-vm-cloudinit.sh 201

# 3. Console öffnen (sollte jetzt funktionieren!)
# Proxmox UI → VM 201 → Console
# Du solltest den Boot-Prozess sehen
```

---

## Changelog für Scripts:

**v1.0.1 - Script Improvements:**
- Fixed: VGA console instead of serial (console now works)
- Fixed: Secure password generation for .env
- Fixed: Better error handling and status messages
- Fixed: IP detection with proper timeout
- Added: Console troubleshooting hints

---

## Wichtig für GitHub:

Alle Scripts sollten diese Header haben:
```bash
#!/bin/bash
#
# VM Migration Tool - [Script Name]
# Version: 1.0.1
# Fixed: VGA console, secure passwords, error handling
#
```

---

## Zusammenfassung:

**Vor den Fixes:**
- Serial Console funktionierte nicht → User sah nichts
- .env wurde falsch erstellt
- Keine guten Fehlermeldungen

**Nach den Fixes:**
- VGA Console funktioniert → User sieht Boot-Prozess
- .env mit sicheren Passwörtern
- Klare Status-Meldungen und Hilfe

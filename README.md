# VMware → Proxmox Migration Tool
## Full Stack Application

Intelligente VM-Migration von VMware nach Proxmox mit Web-GUI, automatischer Validierung und Zeitsteuerung.

---

## 🎯 Features

- ✅ Web-basierte GUI
- ✅ Automatische VM-Migration
- ✅ Batch-Verarbeitung
- ✅ Zeitsteuerung (Sofort / Geplant / Wiederkehrend)
- ✅ 3-stufige Validierung
- ✅ Live-Fortschrittsanzeige
- ✅ REST API

---

## 🏗️ Architektur

```
Frontend (React/TypeScript)
    ↓
Backend (FastAPI/Python)
    ↓
Celery (Async Tasks)
    ↓
PostgreSQL + Redis
```

---

## 🚀 Quick Start

### 1. Repository clonen
```bash
git clone https://github.com/thiemostappen-del/vm-migration-tool.git
cd vm-migration-tool
```

### 2. Environment konfigurieren
```bash
cp .env.example .env
nano .env  # Passwörter anpassen!
```

### 3. Starten
```bash
docker-compose build
docker-compose up -d
```

### 4. Zugriff
- **Frontend:** http://localhost:3000
- **API Docs:** http://localhost:8000/docs

---

## 📁 Projektstruktur

```
vm-migration-tool/
├── backend/
│   ├── app/
│   │   ├── api/              # REST Endpoints
│   │   ├── connectors/       # VMware & Proxmox APIs
│   │   ├── services/         # Business Logic
│   │   ├── tasks/            # Celery Tasks
│   │   ├── models/           # Database Models
│   │   └── schemas/          # Pydantic Schemas
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/       # React Components
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── Dockerfile
│   └── package.json
└── docker-compose.yml
```

---

## 🔧 Development

### Backend entwickeln
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Frontend entwickeln
```bash
cd frontend
npm install
npm run dev
```

---

## 🐳 Docker Commands

```bash
# Alles bauen
docker-compose build

# Starten
docker-compose up -d

# Logs anzeigen
docker-compose logs -f

# Stoppen
docker-compose down

# Neu starten
docker-compose restart

# Container-Status
docker-compose ps
```

---

## 📊 API Endpoints

### Migrations
- `POST /api/migrations/` - Neue Migration erstellen
- `GET /api/migrations/` - Alle Migrationen auflisten
- `GET /api/migrations/{id}` - Migration Details
- `DELETE /api/migrations/{id}` - Migration löschen

### VMware
- `POST /api/vmware/test-connection` - Verbindung testen
- `POST /api/vmware/list-vms` - VMs auflisten

### Proxmox
- `POST /api/proxmox/test-connection` - Verbindung testen
- `POST /api/proxmox/list-nodes` - Nodes auflisten
- `POST /api/proxmox/list-storage` - Storage auflisten

API-Dokumentation: http://localhost:8000/docs

---

## ⚙️ Konfiguration

### .env Datei
```env
DB_PASSWORD=<sicheres-passwort>
SECRET_KEY=<langer-zufälliger-schlüssel>

# Optional: Default-Verbindungen
VMWARE_HOST=vcenter.local
VMWARE_USER=administrator@vsphere.local
VMWARE_PASSWORD=...

PROXMOX_HOST=proxmox.local
PROXMOX_USER=root@pam
PROXMOX_PASSWORD=...
```

---

## 🧪 Testing

```bash
cd backend
pytest
```

---

## 📝 Migration Workflow

1. **Verbindung zu VMware herstellen**
2. **VMs auswählen** (eine oder mehrere)
3. **Proxmox-Ziel konfigurieren**
4. **Hardware-Anpassungen** (optional)
5. **Zeitplan festlegen**
6. **Migration starten**
7. **Validierung** (automatisch)
8. **Fertig!** ✅

---

## 🔒 Sicherheit

⚠️ **Wichtig:**
- Passwörter in `.env` sollten verschlüsselt werden
- HTTPS in Production verwenden
- Firewall-Regeln anpassen
- Regelmäßige Updates

---

## 🐛 Troubleshooting

### Backend startet nicht
```bash
docker-compose logs backend
```

### Frontend lädt nicht
```bash
docker-compose logs frontend
```

### Celery Tasks laufen nicht
```bash
docker-compose logs celery-worker
```

### Datenbank-Probleme
```bash
docker-compose down -v
docker-compose up -d
```

---

## 📖 Weitere Dokumentation

- [Installation Guide](../INSTALLATION.md)
- [API Documentation](http://localhost:8000/docs)
- [Architecture](docs/ARCHITECTURE.md)

---

## 🤝 Contributing

Pull Requests willkommen!

---

## 📄 License

MIT License

---

## 💬 Support

Issues: https://github.com/thiemostappen-del/vm-migration-tool/issues

# Changelog

## v1.0.1 (2025-09-30)

### Fixed
- Added missing `.env.example` file
- Added missing `frontend/tsconfig.node.json` for TypeScript build
- Added missing `frontend/src/vite-env.d.ts` for Vite environment types
- Fixed React import error in `App.tsx` (removed unused React import)
- Fixed Redis connection URLs in `docker-compose.yml` (localhost → redis)
- Fixed PostgreSQL healthcheck in `docker-compose.yml`

### Changed
- Updated `docker-compose.yml` with correct service names in environment variables
- Improved Docker Compose healthchecks

## v1.0.0 (2025-09-30)

### Added
- Initial release
- VMware to Proxmox migration functionality
- Web-based GUI with React/TypeScript
- REST API with FastAPI
- Celery task queue for async migrations
- Docker Compose deployment
- Installation scripts

"""Application configuration"""
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings"""
    
    # Application
    APP_NAME: str = "VM Migration Tool"
    VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "production"
    
    # Security
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    
    # Database
    DATABASE_URL: str
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/0"
    
    # CORS
    CORS_ORIGINS: list = ["http://localhost:3000", "http://localhost:8000"]
    
    # VMware (optional defaults, can be configured via UI)
    VMWARE_HOST: Optional[str] = None
    VMWARE_USER: Optional[str] = None
    VMWARE_PASSWORD: Optional[str] = None
    VMWARE_PORT: int = 443
    VMWARE_VERIFY_SSL: bool = False
    
    # Proxmox (optional defaults, can be configured via UI)
    PROXMOX_HOST: Optional[str] = None
    PROXMOX_USER: Optional[str] = None
    PROXMOX_PASSWORD: Optional[str] = None
    PROXMOX_PORT: int = 8006
    PROXMOX_VERIFY_SSL: bool = False
    
    # Migration Settings
    MAX_CONCURRENT_MIGRATIONS: int = 2
    CHUNK_SIZE_MB: int = 100
    VALIDATION_ENABLED: bool = True
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

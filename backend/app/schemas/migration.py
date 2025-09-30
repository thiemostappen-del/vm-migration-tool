"""Pydantic schemas for API requests/responses"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from app.models.migration_job import JobStatus, ScheduleType


class VMConfigSchema(BaseModel):
    """VM hardware configuration"""
    cpu_cores: Optional[int] = None
    cpu_sockets: Optional[int] = None
    memory_mb: Optional[int] = None
    network_type: Optional[str] = "virtio"
    network_bridge: Optional[str] = "vmbr0"
    thin_provisioning: bool = True


class MigrationJobCreate(BaseModel):
    """Create migration job request"""
    name: str = Field(..., min_length=1, max_length=255)
    
    # Source
    source_host: str
    source_user: str
    source_password: str
    source_vms: List[str] = Field(..., min_items=1)
    
    # Target
    target_host: str
    target_user: str
    target_password: str
    target_node: str
    target_storage: str
    
    # VM configs (optional per-VM overrides)
    vm_configs: Optional[Dict[str, VMConfigSchema]] = None
    
    # Schedule
    schedule_type: ScheduleType = ScheduleType.IMMEDIATE
    scheduled_time: Optional[datetime] = None
    recurring_pattern: Optional[str] = None
    
    # Options
    delete_source_after: bool = False
    validate_transfer: bool = True
    send_notification: bool = False
    notification_email: Optional[str] = None


class MigrationJobResponse(BaseModel):
    """Migration job response"""
    id: int
    name: str
    status: JobStatus
    
    source_host: str
    target_host: str
    target_node: str
    
    schedule_type: ScheduleType
    scheduled_time: Optional[datetime]
    
    total_vms: int
    completed_vms: int
    failed_vms: int
    current_vm: Optional[str]
    progress_percentage: int
    
    total_size_gb: int
    transferred_size_gb: int
    transfer_speed_mbps: int
    
    created_at: datetime
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    
    error_message: Optional[str]
    
    class Config:
        from_attributes = True


class MigrationJobUpdate(BaseModel):
    """Update migration job"""
    status: Optional[JobStatus] = None
    progress_percentage: Optional[int] = None
    current_vm: Optional[str] = None
    completed_vms: Optional[int] = None
    failed_vms: Optional[int] = None
    transferred_size_gb: Optional[int] = None
    transfer_speed_mbps: Optional[int] = None
    error_message: Optional[str] = None


class VMwareConnectionTest(BaseModel):
    """Test VMware connection"""
    host: str
    user: str
    password: str
    port: int = 443
    verify_ssl: bool = False


class ProxmoxConnectionTest(BaseModel):
    """Test Proxmox connection"""
    host: str
    user: str
    password: str
    port: int = 8006
    verify_ssl: bool = False


class VMInfo(BaseModel):
    """VM information"""
    id: str
    name: str
    status: str
    cpu_cores: int
    memory_mb: int
    disk_size_gb: int
    disks: List[Dict[str, Any]]
    networks: List[Dict[str, Any]]
    guest_os: Optional[str] = None


class ValidationResultResponse(BaseModel):
    """Validation result response"""
    job_id: int
    vm_name: str
    level1_passed: bool
    level2_passed: bool
    level3_passed: bool
    checks: Optional[Dict[str, Any]]
    critical_issues: Optional[List[Dict[str, Any]]]
    warnings: Optional[List[Dict[str, Any]]]
    validated_at: datetime
    
    class Config:
        from_attributes = True

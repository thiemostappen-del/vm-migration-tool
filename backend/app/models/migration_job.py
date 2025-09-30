"""Database models for migration jobs"""
from sqlalchemy import Column, Integer, String, DateTime, JSON, Enum, Boolean, Text
from sqlalchemy.sql import func
from datetime import datetime
import enum

from app.database import Base


class JobStatus(str, enum.Enum):
    """Job status enum"""
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    VALIDATING = "validating"
    VALIDATION_FAILED = "validation_failed"


class ScheduleType(str, enum.Enum):
    """Schedule type enum"""
    IMMEDIATE = "immediate"
    SCHEDULED = "scheduled"
    RECURRING = "recurring"


class MigrationJob(Base):
    """Migration job model"""
    __tablename__ = "migration_jobs"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    status = Column(Enum(JobStatus), default=JobStatus.QUEUED, index=True)
    
    # Source configuration
    source_host = Column(String(255), nullable=False)
    source_user = Column(String(255), nullable=False)
    source_vms = Column(JSON, nullable=False)  # List of VM IDs/names
    
    # Target configuration
    target_host = Column(String(255), nullable=False)
    target_node = Column(String(255), nullable=False)
    target_storage = Column(String(255), nullable=False)
    
    # VM configurations (hardware adjustments)
    vm_configs = Column(JSON, nullable=True)  # Per-VM configuration overrides
    
    # Schedule
    schedule_type = Column(Enum(ScheduleType), default=ScheduleType.IMMEDIATE)
    scheduled_time = Column(DateTime, nullable=True)
    recurring_pattern = Column(String(255), nullable=True)  # Cron expression
    
    # Options
    delete_source_after = Column(Boolean, default=False)
    validate_transfer = Column(Boolean, default=True)
    send_notification = Column(Boolean, default=True)
    notification_email = Column(String(255), nullable=True)
    
    # Progress tracking
    total_vms = Column(Integer, default=0)
    completed_vms = Column(Integer, default=0)
    failed_vms = Column(Integer, default=0)
    current_vm = Column(String(255), nullable=True)
    progress_percentage = Column(Integer, default=0)
    
    # Data tracking
    total_size_gb = Column(Integer, default=0)
    transferred_size_gb = Column(Integer, default=0)
    transfer_speed_mbps = Column(Integer, default=0)
    
    # Timing
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    
    # Results
    error_message = Column(Text, nullable=True)
    validation_results = Column(JSON, nullable=True)
    logs = Column(Text, nullable=True)
    
    # Metadata
    created_by = Column(String(255), nullable=True)


class ValidationResult(Base):
    """Validation results for migrated VMs"""
    __tablename__ = "validation_results"
    
    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(Integer, nullable=False, index=True)
    vm_name = Column(String(255), nullable=False)
    
    # Validation levels
    level1_passed = Column(Boolean, default=False)
    level2_passed = Column(Boolean, default=False)
    level3_passed = Column(Boolean, default=False)
    
    # Detailed results
    checks = Column(JSON, nullable=True)
    
    # Issues
    critical_issues = Column(JSON, nullable=True)
    warnings = Column(JSON, nullable=True)
    
    # Timing
    validated_at = Column(DateTime(timezone=True), server_default=func.now())

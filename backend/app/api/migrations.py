"""Migration API endpoints"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from app.database import get_db
from app.models.migration_job import MigrationJob, JobStatus
from app.schemas.migration import (
    MigrationJobCreate,
    MigrationJobResponse,
    MigrationJobUpdate
)
from app.tasks.migration_tasks import run_migration_job

router = APIRouter()


@router.post("/", response_model=MigrationJobResponse, status_code=status.HTTP_201_CREATED)
async def create_migration_job(
    job_data: MigrationJobCreate,
    db: Session = Depends(get_db)
):
    """Create a new migration job"""
    
    # Create job
    job = MigrationJob(
        name=job_data.name,
        status=JobStatus.QUEUED,
        source_host=job_data.source_host,
        source_user=job_data.source_user,
        # Note: In production, encrypt passwords!
        source_password=job_data.source_password,
        source_vms=job_data.source_vms,
        target_host=job_data.target_host,
        target_user=job_data.target_user,
        target_password=job_data.target_password,
        target_node=job_data.target_node,
        target_storage=job_data.target_storage,
        vm_configs=job_data.vm_configs.dict() if job_data.vm_configs else None,
        schedule_type=job_data.schedule_type,
        scheduled_time=job_data.scheduled_time,
        recurring_pattern=job_data.recurring_pattern,
        delete_source_after=job_data.delete_source_after,
        validate_transfer=job_data.validate_transfer,
        send_notification=job_data.send_notification,
        notification_email=job_data.notification_email,
        total_vms=len(job_data.source_vms),
        completed_vms=0,
        failed_vms=0,
        progress_percentage=0
    )
    
    db.add(job)
    db.commit()
    db.refresh(job)
    
    # Start migration task
    if job_data.schedule_type.value == "immediate":
        run_migration_job.delay(job.id)
    elif job_data.schedule_type.value == "scheduled":
        # Schedule for later using ETA
        run_migration_job.apply_async(
            args=[job.id],
            eta=job_data.scheduled_time
        )
    
    return job


@router.get("/", response_model=List[MigrationJobResponse])
async def list_migration_jobs(
    skip: int = 0,
    limit: int = 100,
    status_filter: JobStatus = None,
    db: Session = Depends(get_db)
):
    """List all migration jobs"""
    query = db.query(MigrationJob)
    
    if status_filter:
        query = query.filter(MigrationJob.status == status_filter)
    
    jobs = query.order_by(MigrationJob.created_at.desc()).offset(skip).limit(limit).all()
    return jobs


@router.get("/{job_id}", response_model=MigrationJobResponse)
async def get_migration_job(
    job_id: int,
    db: Session = Depends(get_db)
):
    """Get a specific migration job"""
    job = db.query(MigrationJob).filter(MigrationJob.id == job_id).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found"
        )
    
    return job


@router.patch("/{job_id}", response_model=MigrationJobResponse)
async def update_migration_job(
    job_id: int,
    job_update: MigrationJobUpdate,
    db: Session = Depends(get_db)
):
    """Update a migration job"""
    job = db.query(MigrationJob).filter(MigrationJob.id == job_id).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found"
        )
    
    # Update fields
    update_data = job_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(job, field, value)
    
    db.commit()
    db.refresh(job)
    
    return job


@router.delete("/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_migration_job(
    job_id: int,
    db: Session = Depends(get_db)
):
    """Delete a migration job"""
    job = db.query(MigrationJob).filter(MigrationJob.id == job_id).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found"
        )
    
    # Only allow deletion of completed/failed jobs
    if job.status in [JobStatus.RUNNING, JobStatus.VALIDATING]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete running job"
        )
    
    db.delete(job)
    db.commit()
    
    return None


@router.post("/{job_id}/cancel")
async def cancel_migration_job(
    job_id: int,
    db: Session = Depends(get_db)
):
    """Cancel a running migration job"""
    job = db.query(MigrationJob).filter(MigrationJob.id == job_id).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found"
        )
    
    if job.status not in [JobStatus.QUEUED, JobStatus.RUNNING]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Job cannot be cancelled"
        )
    
    # TODO: Implement actual task cancellation
    job.status = JobStatus.CANCELLED
    db.commit()
    
    return {"message": "Job cancelled"}

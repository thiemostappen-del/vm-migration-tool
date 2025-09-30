"""Celery tasks for migrations"""
from celery import current_task
from app.celery_app import celery_app
from app.services.migration_service import MigrationService
from app.database import SessionLocal
from app.models.migration_job import MigrationJob, JobStatus
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


@celery_app.task(bind=True)
def run_migration_job(self, job_id: int):
    """
    Run a migration job
    
    Args:
        job_id: Database ID of the migration job
    """
    db = SessionLocal()
    
    try:
        # Get job from database
        job = db.query(MigrationJob).filter(MigrationJob.id == job_id).first()
        if not job:
            raise ValueError(f"Job {job_id} not found")
        
        # Update job status
        job.status = JobStatus.RUNNING
        job.started_at = datetime.now()
        db.commit()
        
        logger.info(f"Starting migration job {job_id}: {job.name}")
        
        # Create migration service
        migration_service = MigrationService()
        
        # Migrate each VM
        for idx, vm_name in enumerate(job.source_vms):
            logger.info(f"Migrating VM {idx+1}/{len(job.source_vms)}: {vm_name}")
            
            job.current_vm = vm_name
            db.commit()
            
            # Get VM-specific config
            vm_config = None
            if job.vm_configs and vm_name in job.vm_configs:
                vm_config = job.vm_configs[vm_name]
            
            def progress_callback(percentage: int, message: str):
                """Update job progress"""
                # Calculate overall progress
                vm_progress = (idx / len(job.source_vms)) * 100
                current_vm_progress = (percentage / 100) * (100 / len(job.source_vms))
                overall_progress = int(vm_progress + current_vm_progress)
                
                job.progress_percentage = overall_progress
                db.commit()
                
                # Update Celery task state
                self.update_state(
                    state='PROGRESS',
                    meta={
                        'current': overall_progress,
                        'total': 100,
                        'status': message,
                        'current_vm': vm_name
                    }
                )
            
            try:
                # Migrate VM
                result = migration_service.migrate_vm(
                    source_host=job.source_host,
                    source_user=job.source_user,
                    source_password=job.source_password,  # Note: Should be encrypted
                    source_vm_name=vm_name,
                    target_host=job.target_host,
                    target_user=job.target_user,
                    target_password=job.target_password,  # Note: Should be encrypted
                    target_node=job.target_node,
                    target_storage=job.target_storage,
                    vm_config=vm_config,
                    progress_callback=progress_callback
                )
                
                if result['success']:
                    job.completed_vms += 1
                    logger.info(f"VM {vm_name} migrated successfully")
                else:
                    job.failed_vms += 1
                    logger.error(f"VM {vm_name} migration failed: {result.get('error')}")
                
            except Exception as e:
                logger.error(f"Exception during migration of {vm_name}: {str(e)}")
                job.failed_vms += 1
                job.error_message = str(e)
            
            db.commit()
        
        # Mark job as completed
        job.status = JobStatus.COMPLETED if job.failed_vms == 0 else JobStatus.FAILED
        job.completed_at = datetime.now()
        job.progress_percentage = 100
        job.current_vm = None
        db.commit()
        
        logger.info(f"Migration job {job_id} completed. Success: {job.completed_vms}, Failed: {job.failed_vms}")
        
        # Send notification if configured
        if job.send_notification and job.notification_email:
            send_notification.delay(job_id)
        
        return {
            'job_id': job_id,
            'status': 'completed',
            'completed_vms': job.completed_vms,
            'failed_vms': job.failed_vms
        }
        
    except Exception as e:
        logger.error(f"Migration job {job_id} failed: {str(e)}")
        
        # Update job status
        job = db.query(MigrationJob).filter(MigrationJob.id == job_id).first()
        if job:
            job.status = JobStatus.FAILED
            job.error_message = str(e)
            job.completed_at = datetime.now()
            db.commit()
        
        raise
    
    finally:
        db.close()


@celery_app.task
def send_notification(job_id: int):
    """Send email notification about job completion"""
    db = SessionLocal()
    
    try:
        job = db.query(MigrationJob).filter(MigrationJob.id == job_id).first()
        if not job:
            return
        
        # TODO: Implement email sending
        logger.info(f"Sending notification for job {job_id} to {job.notification_email}")
        
        # Placeholder for email implementation
        # send_email(
        #     to=job.notification_email,
        #     subject=f"Migration Job {job.name} - {job.status}",
        #     body=f"Job completed with {job.completed_vms} successful and {job.failed_vms} failed migrations"
        # )
        
    finally:
        db.close()


@celery_app.task
def validate_migration(job_id: int, vm_name: str):
    """Validate a migrated VM"""
    # TODO: Implement validation logic
    logger.info(f"Validating VM {vm_name} for job {job_id}")
    pass

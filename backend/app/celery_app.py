"""Celery application"""
from celery import Celery
from app.config import settings

celery_app = Celery(
    'vm_migration_tool',
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=['app.tasks.migration_tasks']
)

celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600 * 12,  # 12 hours max
    worker_max_tasks_per_child=10,
)

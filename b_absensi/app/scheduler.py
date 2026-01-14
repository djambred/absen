from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from app.services.auto_checkout_service import AutoCheckoutService
from app.services.leave_quota_service import LeaveQuotaService
from app.database import SessionLocal
import logging
import pytz

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler()

# Set timezone to Jakarta (UTC+7)
JAKARTA_TZ = pytz.timezone('Asia/Jakarta')

def reset_leave_quotas_job():
    """Job to reset leave quotas at the start of new year"""
    db = SessionLocal()
    try:
        count = LeaveQuotaService.reset_annual_quotas(db)
        logger.info(f"Annual leave quotas reset completed: {count} users processed")
    except Exception as e:
        logger.error(f"Error in reset_leave_quotas_job: {e}")
    finally:
        db.close()

def start_scheduler():
    """
    Start the background scheduler for automatic tasks
    """
    try:
        # Schedule auto-checkout to run at midnight (00:00) Jakarta time every day
        scheduler.add_job(
            AutoCheckoutService.auto_checkout_users,
            CronTrigger(hour=0, minute=0, timezone=JAKARTA_TZ),  # Runs at 00:00 Jakarta time
            id='auto_checkout',
            name='Auto checkout users who forgot to check out',
            replace_existing=True
        )
        
        # Schedule leave quota reset to run on January 1st at 00:01 Jakarta time
        scheduler.add_job(
            reset_leave_quotas_job,
            CronTrigger(month=1, day=1, hour=0, minute=1, timezone=JAKARTA_TZ),  # January 1st at 00:01 Jakarta time
            id='reset_leave_quotas',
            name='Reset annual leave quotas for new year',
            replace_existing=True
        )
        
        scheduler.start()
        logger.info("Scheduler started successfully")
        logger.info("Scheduled jobs:")
        logger.info("  - Auto-checkout: Daily at 00:00 (Jakarta time)")
        logger.info("  - Leave quota reset: January 1st at 00:01")
        
    except Exception as e:
        logger.error(f"Error starting scheduler: {e}")

def stop_scheduler():
    """
    Stop the background scheduler
    """
    try:
        scheduler.shutdown()
        logger.info("Scheduler stopped")
    except Exception as e:
        logger.error(f"Error stopping scheduler: {e}")

from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta
import pytz
from app.models.absensi import LeaveQuota
from app.models.user import User
from app.services.holiday_service import HolidayService
import logging

logger = logging.getLogger(__name__)

TZ = pytz.timezone('Asia/Jakarta')

def get_jakarta_time():
    """Get current datetime in Asia/Jakarta timezone"""
    return datetime.now(TZ)

class LeaveQuotaService:
    """Service for managing annual leave quotas"""
    
    @staticmethod
    def get_or_create_quota(db: Session, user_id: str, year: int = None) -> LeaveQuota:
        """Get or create leave quota for a user for a specific year"""
        if year is None:
            year = get_jakarta_time().year
        
        quota = db.query(LeaveQuota).filter(
            LeaveQuota.user_id == user_id,
            LeaveQuota.year == year
        ).first()
        
        if not quota:
            quota = LeaveQuota(
                user_id=user_id,
                year=year,
                total_quota=12,
                used_quota=0,
                remaining_quota=12
            )
            db.add(quota)
            db.commit()
            db.refresh(quota)
            logger.info(f"Created new leave quota for user {user_id} for year {year}")
        
        return quota
    
    @staticmethod
    def deduct_quota(db: Session, user_id: str, days: int, year: int = None) -> bool:
        """
        Deduct days from user's annual leave quota
        Returns True if successful, False if insufficient quota
        """
        quota = LeaveQuotaService.get_or_create_quota(db, user_id, year)
        
        if quota.remaining_quota < days:
            logger.warning(f"Insufficient quota for user {user_id}: need {days}, have {quota.remaining_quota}")
            return False
        
        quota.used_quota += days
        quota.remaining_quota -= days
        db.commit()
        logger.info(f"Deducted {days} days from user {user_id} quota. Remaining: {quota.remaining_quota}")
        return True
    
    @staticmethod
    def restore_quota(db: Session, user_id: str, days: int, year: int = None):
        """Restore days to user's quota (e.g., when leave is cancelled)"""
        quota = LeaveQuotaService.get_or_create_quota(db, user_id, year)
        
        quota.used_quota -= days
        quota.remaining_quota += days
        
        # Ensure we don't exceed total quota
        if quota.remaining_quota > quota.total_quota:
            quota.remaining_quota = quota.total_quota
            quota.used_quota = 0
        
        db.commit()
        logger.info(f"Restored {days} days to user {user_id} quota. Remaining: {quota.remaining_quota}")
    
    @staticmethod
    def reset_annual_quotas(db: Session):
        """
        Reset all users' leave quotas for the new year
        This should run at the beginning of each year (e.g., January 1st)
        Does NOT carry over remaining quota from previous year
        """
        current_year = get_jakarta_time().year
        
        # Get all active users
        users = db.query(User).filter(User.is_active == True).all()
        
        count = 0
        for user in users:
            # Check if quota exists for current year
            existing_quota = db.query(LeaveQuota).filter(
                LeaveQuota.user_id == user.id,
                LeaveQuota.year == current_year
            ).first()
            
            if not existing_quota:
                # Create new quota for the year
                new_quota = LeaveQuota(
                    user_id=user.id,
                    year=current_year,
                    total_quota=12,
                    used_quota=0,
                    remaining_quota=12
                )
                db.add(new_quota)
                count += 1
        
        db.commit()
        logger.info(f"Reset leave quotas for {count} users for year {current_year}")
        return count
    
    @staticmethod
    def get_user_quota_info(db: Session, user_id: str, year: int = None) -> dict:
        """Get detailed quota information for a user"""
        quota = LeaveQuotaService.get_or_create_quota(db, user_id, year)
        
        return {
            "year": quota.year,
            "total_quota": quota.total_quota,
            "used_quota": quota.used_quota,
            "remaining_quota": quota.remaining_quota,
            "percentage_used": round((quota.used_quota / quota.total_quota) * 100, 2) if quota.total_quota > 0 else 0
        }
    
    @staticmethod
    def calculate_working_days(start_date: date, end_date: date) -> int:
        """
        Calculate number of working days between two dates
        Excludes weekends (Saturday and Sunday) and public holidays
        """
        if start_date > end_date:
            return 0
        
        days = 0
        current = start_date
        
        while current <= end_date:
            # Skip weekends and holidays
            if not HolidayService.is_non_working_day(current):
                days += 1
            current = current + timedelta(days=1)
        
        return days

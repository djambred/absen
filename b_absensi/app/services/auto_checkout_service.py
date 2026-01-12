from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from datetime import datetime, date, time
import pytz
from app.database import SessionLocal
from app.models.absensi import Attendance, AttendanceStatus
from app.models.user import User
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TZ = pytz.timezone('Asia/Jakarta')

def get_jakarta_time():
    """Get current datetime in Asia/Jakarta timezone"""
    return datetime.now(TZ)

class AutoCheckoutService:
    """Service for handling automatic checkout"""
    
    @staticmethod
    def auto_checkout_users():
        """
        Automatically check out users who forgot to check out.
        This runs at midnight (00:00) every day.
        """
        db: Session = SessionLocal()
        try:
            # Get yesterday's date (since this runs at midnight) in Jakarta timezone
            yesterday = get_jakarta_time().date()
            
            logger.info(f"Starting auto-checkout process for date: {yesterday}")
            
            # Find all attendances from yesterday that don't have check_out_time
            incomplete_attendances = db.query(Attendance).filter(
                and_(
                    func.date(Attendance.check_in_time) == yesterday,
                    Attendance.check_out_time.is_(None)
                )
            ).all()
            
            if not incomplete_attendances:
                logger.info("No incomplete attendances found")
                return
            
            logger.info(f"Found {len(incomplete_attendances)} incomplete attendances")
            
            # Auto check-out each one
            for attendance in incomplete_attendances:
                try:
                    user = db.query(User).filter(User.id == attendance.user_id).first()
                    
                    # Set checkout time to 23:59:59 of the same day (Jakarta time)
                    checkout_time = TZ.localize(datetime.combine(
                        attendance.check_in_time.date(),
                        time(23, 59, 59)
                    ))
                    
                    # Update attendance with auto checkout
                    attendance.check_out_time = checkout_time
                    attendance.check_out_latitude = attendance.check_in_latitude
                    attendance.check_out_longitude = attendance.check_in_longitude
                    attendance.check_out_location = f"{attendance.check_in_location} (Auto Checkout)"
                    attendance.check_out_photo_url = attendance.check_in_photo_url  # Use same photo
                    attendance.status = AttendanceStatus.INCOMPLETE  # Mark as incomplete
                    
                    db.commit()
                    
                    logger.info(
                        f"Auto checkout completed for user {user.name} (ID: {user.id}) "
                        f"at {checkout_time}"
                    )
                    
                except Exception as e:
                    logger.error(f"Error auto-checking out attendance ID {attendance.id}: {e}")
                    db.rollback()
                    continue
            
            logger.info("Auto-checkout process completed successfully")
            
        except Exception as e:
            logger.error(f"Error in auto_checkout_users: {e}")
            db.rollback()
        finally:
            db.close()
    
    @staticmethod
    def manual_auto_checkout_for_date(target_date: date):
        """
        Manually trigger auto-checkout for a specific date.
        Useful for testing or fixing missing checkouts.
        """
        db: Session = SessionLocal()
        try:
            logger.info(f"Manual auto-checkout triggered for date: {target_date}")
            
            incomplete_attendances = db.query(Attendance).filter(
                and_(
                    func.date(Attendance.check_in_time) == target_date,
                    Attendance.check_out_time.is_(None)
                )
            ).all()
            
            if not incomplete_attendances:
                logger.info(f"No incomplete attendances found for {target_date}")
                return {"processed": 0, "date": str(target_date)}
            
            count = 0
            for attendance in incomplete_attendances:
                try:
                    checkout_time = TZ.localize(datetime.combine(
                        attendance.check_in_time.date(),
                        time(23, 59, 59)
                    ))
                    
                    attendance.check_out_time = checkout_time
                    attendance.check_out_latitude = attendance.check_in_latitude
                    attendance.check_out_longitude = attendance.check_in_longitude
                    attendance.check_out_location = f"{attendance.check_in_location} (Auto Checkout)"
                    attendance.check_out_photo_url = attendance.check_in_photo_url
                    attendance.status = AttendanceStatus.INCOMPLETE
                    
                    db.commit()
                    count += 1
                    
                except Exception as e:
                    logger.error(f"Error processing attendance ID {attendance.id}: {e}")
                    db.rollback()
                    continue
            
            logger.info(f"Manual auto-checkout completed: {count} attendances processed")
            return {"processed": count, "date": str(target_date)}
            
        except Exception as e:
            logger.error(f"Error in manual_auto_checkout_for_date: {e}")
            db.rollback()
            return {"error": str(e)}
        finally:
            db.close()

"""
Notification Service - Handle push notifications to users
"""
import logging
from typing import Optional
from sqlalchemy.orm import Session
from datetime import datetime
from app.database import SessionLocal
from app.models.user import User
from app.models.absensi import Leave, Task

logger = logging.getLogger(__name__)


class NotificationService:
    """Service for managing notifications"""
    
    @staticmethod
    def notify_leave_approved(db: Session, leave_id: str):
        """Send notification when leave is approved"""
        try:
            from app.models.absensi import Leave
            leave = db.query(Leave).filter(Leave.id == leave_id).first()
            if not leave:
                return
            
            user = db.query(User).filter(User.id == leave.user_id).first()
            if not user:
                return
            
            message = f"Pengajuan {leave.leave_type} Anda telah disetujui"
            logger.info(f"Notification: {message} to {user.email}")
            
            # TODO: Integrate with Firebase Cloud Messaging or other notification service
            # send_push_notification(user.fcm_token, message)
            
        except Exception as e:
            logger.error(f"Error sending leave approval notification: {e}")
    
    @staticmethod
    def notify_leave_rejected(db: Session, leave_id: str, reason: str = ""):
        """Send notification when leave is rejected"""
        try:
            from app.models.absensi import Leave
            leave = db.query(Leave).filter(Leave.id == leave_id).first()
            if not leave:
                return
            
            user = db.query(User).filter(User.id == leave.user_id).first()
            if not user:
                return
            
            message = f"Pengajuan {leave.leave_type} Anda ditolak. Alasan: {reason}" if reason else f"Pengajuan {leave.leave_type} Anda ditolak"
            logger.info(f"Notification: {message} to {user.email}")
            
            # TODO: Integrate with Firebase Cloud Messaging or other notification service
            # send_push_notification(user.fcm_token, message)
            
        except Exception as e:
            logger.error(f"Error sending leave rejection notification: {e}")
    
    @staticmethod
    def notify_task_assigned(db: Session, task_id: str):
        """Send notification when task is assigned"""
        try:
            task = db.query(Task).filter(Task.id == task_id).first()
            if not task:
                return
            
            user = db.query(User).filter(User.id == task.assigned_to_id).first()
            if not user:
                return
            
            message = f"Anda ditugaskan tugas baru: {task.title}"
            logger.info(f"Notification: {message} to {user.email}")
            
            # TODO: Integrate with Firebase Cloud Messaging or other notification service
            # send_push_notification(user.fcm_token, message)
            
        except Exception as e:
            logger.error(f"Error sending task assignment notification: {e}")
    
    @staticmethod
    def notify_task_completed(db: Session, task_id: str):
        """Send notification when assigned task is completed"""
        try:
            task = db.query(Task).filter(Task.id == task_id).first()
            if not task:
                return
            
            user = db.query(User).filter(User.id == task.assigned_by_id).first()
            if not user:
                return
            
            message = f"Tugas '{task.title}' telah diselesaikan oleh {db.query(User).filter(User.id == task.assigned_to_id).first().name}"
            logger.info(f"Notification: {message} to {user.email}")
            
            # TODO: Integrate with Firebase Cloud Messaging or other notification service
            # send_push_notification(user.fcm_token, message)
            
        except Exception as e:
            logger.error(f"Error sending task completion notification: {e}")
    
    @staticmethod
    def notify_pending_approval(db: Session, leave_id: str):
        """Send notification to supervisor about pending leave approval"""
        try:
            from app.models.absensi import Leave
            leave = db.query(Leave).filter(Leave.id == leave_id).first()
            if not leave:
                return
            
            supervisor = db.query(User).filter(User.id == leave.supervisor_id).first()
            if not supervisor:
                return
            
            submitter = db.query(User).filter(User.id == leave.user_id).first()
            message = f"Ada pengajuan {leave.leave_type} dari {submitter.name} yang menunggu persetujuan Anda"
            logger.info(f"Notification: {message} to {supervisor.email}")
            
            # TODO: Integrate with Firebase Cloud Messaging or other notification service
            # send_push_notification(supervisor.fcm_token, message)
            
        except Exception as e:
            logger.error(f"Error sending pending approval notification: {e}")


# TODO: Implement Firebase Cloud Messaging integration
"""
def send_push_notification(fcm_token: str, message: str):
    '''Send push notification using Firebase Cloud Messaging'''
    try:
        import firebase_admin
        from firebase_admin import messaging
        
        if not fcm_token:
            return
        
        message_obj = messaging.Message(
            notification=messaging.Notification(
                title="Absensi MNC",
                body=message,
            ),
            token=fcm_token,
        )
        
        response = messaging.send(message_obj)
        logger.info(f"Notification sent: {response}")
    except Exception as e:
        logger.error(f"Error sending push notification: {e}")
"""

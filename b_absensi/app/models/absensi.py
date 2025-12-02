from sqlalchemy import Column, String, Float, DateTime, Enum, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum
from app.database import Base

class AttendanceStatus(str, enum.Enum):
    ON_TIME = "on_time"
    LATE = "late"
    ABSENT = "absent"

class Attendance(Base):
    __tablename__ = "attendances"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    
    check_in_time = Column(DateTime, nullable=False)
    check_in_latitude = Column(Float, nullable=False)
    check_in_longitude = Column(Float, nullable=False)
    check_in_location = Column(String(255), nullable=False)
    check_in_photo_url = Column(String(512))
    
    check_out_time = Column(DateTime, nullable=True)
    check_out_latitude = Column(Float, nullable=True)
    check_out_longitude = Column(Float, nullable=True)
    check_out_location = Column(String(255), nullable=True)
    check_out_photo_url = Column(String(512), nullable=True)
    
    required_checkout_time = Column(DateTime, nullable=False)  # Waktu checkout yang seharusnya
    status = Column(String(20), default="on_time")
    notes = Column(String(1024), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = relationship("User", back_populates="attendances")

class LeaveStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED_LEVEL_1 = "approved_level_1"
    APPROVED_LEVEL_2 = "approved_level_2"
    REJECTED = "rejected"

class Leave(Base):
    __tablename__ = "leaves"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    
    leave_type = Column(String(50), nullable=False)
    category = Column(String(50), nullable=False)
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime, nullable=False)
    reason = Column(String(1024), nullable=False)
    attachment = Column(String(512), nullable=True)
    
    status = Column(String(30), default="pending")
    approved_by_level_1 = Column(String(36), nullable=True)
    approved_by_level_2 = Column(String(36), nullable=True)
    rejected_by = Column(String(36), nullable=True)
    rejection_reason = Column(String(1024), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = relationship("User", back_populates="leaves")

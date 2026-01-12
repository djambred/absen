from sqlalchemy import Column, String, Float, DateTime, Enum, ForeignKey, Integer, Text, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum
import pytz
from app.database import Base

TZ = pytz.timezone('Asia/Jakarta')

def get_jakarta_time():
    return datetime.now(TZ)

class AttendanceStatus(str, enum.Enum):
    ON_TIME = "on_time"
    LATE = "late"
    ABSENT = "absent"
    INCOMPLETE = "incomplete"  # For auto-checkout

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
    created_at = Column(DateTime, default=get_jakarta_time)
    updated_at = Column(DateTime, default=get_jakarta_time, onupdate=get_jakarta_time)
    
    user = relationship("User", back_populates="attendances")

class LeaveType(str, enum.Enum):
    CUTI = "cuti"  # Annual leave - 12 days/year
    SAKIT = "sakit"  # Sick leave - requires medical certificate
    IZIN = "izin"  # Permission leave

class LeaveCategory(str, enum.Enum):
    # For CUTI
    CUTI_TAHUNAN = "cuti_tahunan"
    
    # For SAKIT
    SAKIT_DENGAN_SURAT = "sakit_dengan_surat"  # With medical certificate
    SAKIT_TANPA_SURAT = "sakit_tanpa_surat"  # Without certificate, deduct from cuti
    
    # For IZIN
    DINAS_LUAR = "dinas_luar"  # Official business trip
    KEPERLUAN_PRIBADI = "keperluan_pribadi"  # Personal matters

class LeaveStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED_BY_SUPERVISOR = "approved_by_supervisor"  # Level 1
    APPROVED_BY_HR = "approved_by_hr"  # Level 2 (final)
    REJECTED = "rejected"
    CANCELLED = "cancelled"

class Leave(Base):
    __tablename__ = "leaves"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    
    leave_type = Column(String(50), nullable=False)  # CUTI, SAKIT, IZIN
    category = Column(String(50), nullable=False)  # Specific category
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime, nullable=False)
    total_days = Column(Integer, nullable=False)  # Calculated working days
    reason = Column(Text, nullable=False)
    attachment_url = Column(String(512), nullable=True)  # For medical certificate or other docs
    
    status = Column(String(50), default="pending")
    
    # Approval tracking
    approved_by_level_1 = Column(String(36), ForeignKey("users.id"), nullable=True)  # Supervisor
    approved_at_level_1 = Column(DateTime, nullable=True)
    approval_notes_level_1 = Column(Text, nullable=True)
    
    approved_by_level_2 = Column(String(36), ForeignKey("users.id"), nullable=True)  # HR
    approved_at_level_2 = Column(DateTime, nullable=True)
    approval_notes_level_2 = Column(Text, nullable=True)
    
    rejected_by = Column(String(36), ForeignKey("users.id"), nullable=True)
    rejected_at = Column(DateTime, nullable=True)
    rejection_reason = Column(Text, nullable=True)
    
    deducted_from_quota = Column(Boolean, default=False)  # Whether it deducts from annual leave quota
    quota_year = Column(Integer, nullable=True)  # Which year's quota
    
    created_at = Column(DateTime, default=get_jakarta_time)
    updated_at = Column(DateTime, default=get_jakarta_time, onupdate=get_jakarta_time)
    
    # Relationships
    user = relationship("User", back_populates="leaves", foreign_keys=[user_id])
    approver_level_1_user = relationship("User", back_populates="leaves_to_approve_l1", foreign_keys=[approved_by_level_1])
    approver_level_2_user = relationship("User", back_populates="leaves_to_approve_l2", foreign_keys=[approved_by_level_2])

class LeaveQuota(Base):
    """Annual leave quota tracking - resets every year"""
    __tablename__ = "leave_quotas"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    year = Column(Integer, nullable=False)  # e.g., 2026
    total_quota = Column(Integer, default=12)  # Total days per year
    used_quota = Column(Integer, default=0)  # Days used
    remaining_quota = Column(Integer, default=12)  # Days remaining
    
    created_at = Column(DateTime, default=get_jakarta_time)
    updated_at = Column(DateTime, default=get_jakarta_time, onupdate=get_jakarta_time)
    
    user = relationship("User", back_populates="leave_quotas")
    
    __table_args__ = (
        # Unique constraint: one quota record per user per year
        {'sqlite_autoincrement': True},
    )

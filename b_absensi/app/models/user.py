from sqlalchemy import Column, String, Boolean, DateTime, Enum, Table, ForeignKey, Integer
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum
import pytz
from app.database import Base

TZ = pytz.timezone('Asia/Jakarta')

def get_jakarta_time():
    return datetime.now(TZ)

class UserRole(str, enum.Enum):
    DOSEN = "dosen"
    STAFF_IT = "staff_it"
    KEPALA_IT = "kepala_it"
    STAFF_HR = "staff_hr"
    KEPALA_HR = "kepala_hr"
    STAFF_KEUANGAN = "staff_keuangan"
    KEPALA_KEUANGAN = "kepala_keuangan"
    ADMIN = "admin"

class PositionCategory(str, enum.Enum):
    AKADEMIK = "akademik"
    NON_AKADEMIK = "non_akademik"

# Association table for user positions (many-to-many)
user_positions = Table(
    'user_positions',
    Base.metadata,
    Column('user_id', String(36), ForeignKey('users.id'), primary_key=True),
    Column('position_id', String(36), ForeignKey('positions.id'), primary_key=True),
    Column('is_primary', Boolean, default=False),  # Primary position for approval hierarchy
    Column('assigned_at', DateTime, default=get_jakarta_time)
)

class Position(Base):
    """Position/Jabatan model for multi-role support"""
    __tablename__ = "positions"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    code = Column(String(50), unique=True, nullable=False)  # e.g., DOSEN, STAFF_IT, KEPALA_IT
    name = Column(String(255), nullable=False)  # e.g., "Dosen", "Staff IT", "Kepala IT"
    category = Column(String(20), nullable=False)  # akademik or non_akademik
    department = Column(String(255), nullable=True)  # e.g., "IT", "HR", "Fakultas Teknik"
    level = Column(Integer, default=1)  # 1=staff/dosen, 2=kepala, 3=dekan/direktur, etc
    approver_position_id = Column(String(36), ForeignKey('positions.id'), nullable=True)  # Who approves leaves for this position
    created_at = Column(DateTime, default=get_jakarta_time)
    
    users = relationship("User", secondary=user_positions, back_populates="positions")
    approver_position = relationship("Position", remote_side=[id])

class User(Base):
    __tablename__ = "users"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    name = Column(String(255), nullable=False)
    nip = Column(String(50), unique=True, nullable=False, index=True)
    department = Column(String(255))  # Main department
    pin_hash = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    supervisor_id = Column(String(36), ForeignKey('users.id'), nullable=True)  # Direct supervisor
    created_at = Column(DateTime, default=get_jakarta_time)
    updated_at = Column(DateTime, default=get_jakarta_time, onupdate=get_jakarta_time)
    
    # Relationships
    positions = relationship("Position", secondary=user_positions, back_populates="users")
    attendances = relationship("Attendance", back_populates="user", cascade="all, delete-orphan")
    leaves = relationship("Leave", back_populates="user", cascade="all, delete-orphan", foreign_keys="Leave.user_id")
    leave_quotas = relationship("LeaveQuota", back_populates="user", cascade="all, delete-orphan")
    
    # Self-referential for supervisor
    subordinates = relationship("User", backref="supervisor", remote_side=[id])
    
    # Leaves where this user is approver
    leaves_to_approve_l1 = relationship("Leave", back_populates="approver_level_1_user", foreign_keys="Leave.approved_by_level_1")
    leaves_to_approve_l2 = relationship("Leave", back_populates="approver_level_2_user", foreign_keys="Leave.approved_by_level_2")


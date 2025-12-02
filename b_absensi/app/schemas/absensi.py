from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class AttendanceCheckIn(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location: str

class AttendanceCheckOut(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location: str

class AttendanceResponse(BaseModel):
    id: str
    user_id: str
    check_in_time: datetime
    check_in_latitude: float
    check_in_longitude: float
    check_in_location: str
    check_in_photo_url: Optional[str] = None
    check_out_time: Optional[datetime] = None
    check_out_latitude: Optional[float] = None
    check_out_longitude: Optional[float] = None
    check_out_location: Optional[str] = None
    check_out_photo_url: Optional[str] = None
    required_checkout_time: datetime
    status: str
    notes: Optional[str] = None
    
    class Config:
        from_attributes = True

class AttendanceHistory(BaseModel):
    data: list[AttendanceResponse]
    total: int
    page: int = 1
    page_size: int = 30

class LeaveRequest(BaseModel):
    leave_type: str
    category: str
    start_date: datetime
    end_date: datetime
    reason: str

class LeaveResponse(BaseModel):
    id: str
    user_id: str
    leave_type: str
    category: str
    start_date: datetime
    end_date: datetime
    reason: str
    attachment: Optional[str] = None
    status: str
    approved_by_level_1: Optional[str] = None
    approved_by_level_2: Optional[str] = None
    rejected_by: Optional[str] = None
    rejection_reason: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

class LeaveList(BaseModel):
    data: list[LeaveResponse]
    total: int
    page: int = 1
    page_size: int = 30

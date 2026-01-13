from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from datetime import datetime, time, date, timedelta
from typing import Optional
import os
import uuid
import pytz
from app.database import get_db
from app.models.user import User
from app.models.absensi import Attendance, AttendanceStatus
from app.schemas.absensi import AttendanceResponse, AttendanceHistory
from app.services.location_service import LocationService
from app.services.auto_checkout_service import AutoCheckoutService
from app.middleware.auth_middleware import get_current_user

router = APIRouter()

UPLOAD_DIR = "uploads"
TZ = pytz.timezone('Asia/Jakarta')

def get_jakarta_time():
    """Get current datetime in Asia/Jakarta timezone"""
    return datetime.now(TZ)

def save_photo(file: UploadFile) -> str:
    """Save uploaded photo"""
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    ext = os.path.splitext(file.filename)[1]
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)
    
    with open(filepath, "wb") as f:
        f.write(file.file.read())
    
    return filename

def calculate_required_checkout(check_in_time: datetime) -> datetime:
    """
    Calculate required checkout time based on check-in time (Jakarta timezone):
    - Check in <= 7:30 -> Check out at 17:00
    - Check in 8:00-10:00 -> Check out at 19:00
    - Check in > 10:00 -> Check out at 19:00
    """
    check_in_hour = check_in_time.time()
    today = check_in_time.date()
    
    if check_in_hour <= time(7, 30):
        return TZ.localize(datetime.combine(today, time(17, 0)))
    else:
        # All other times (8:00-10:00 or after 10:00) -> Check out at 19:00
        return TZ.localize(datetime.combine(today, time(19, 0)))

@router.post("/check-in", response_model=AttendanceResponse)
async def check_in(
    latitude: float = Form(...),
    longitude: float = Form(...),
    location: str = Form(...),
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check in with GPS and photo"""
    # Check if already checked in today
    today = date.today()
    existing = db.query(Attendance).filter(
        and_(
            Attendance.user_id == current_user.id,
            func.date(Attendance.check_in_time) == today
        )
    ).first()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Anda sudah check-in hari ini"
        )
    
    # Validate location
    is_valid, location_name = LocationService.validate_location(latitude, longitude)
    if not is_valid:
        nearest = LocationService.get_nearest_location(latitude, longitude)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Lokasi Anda tidak valid untuk check-in. Lokasi terdekat: {nearest['name']} ({nearest['distance']} km)"
        )
    
    # Save photo
    photo_filename = save_photo(photo)
    
    # Check time and calculate status (Jakarta timezone)
    check_in_time = get_jakarta_time()
    current_time = check_in_time.time()
    
    # Determine status
    if current_time <= time(7, 30):
        status_value = AttendanceStatus.ON_TIME
    else:
        # Any check-in after 7:30 is marked as late
        status_value = AttendanceStatus.LATE
    
    # Calculate required checkout time
    required_checkout = calculate_required_checkout(check_in_time)
    
    # Create attendance
    attendance = Attendance(
        user_id=current_user.id,
        check_in_time=check_in_time,
        check_in_latitude=latitude,
        check_in_longitude=longitude,
        check_in_location=location_name,
        check_in_photo_url=photo_filename,
        required_checkout_time=required_checkout,
        status=status_value
    )
    
    db.add(attendance)
    db.commit()
    db.refresh(attendance)
    
    return AttendanceResponse.model_validate(attendance)

@router.post("/check-out", response_model=AttendanceResponse)
async def check_out(
    latitude: float = Form(...),
    longitude: float = Form(...),
    location: str = Form(...),
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check out with GPS and photo"""
    # Find today's attendance
    today = date.today()
    attendance = db.query(Attendance).filter(
        and_(
            Attendance.user_id == current_user.id,
            func.date(Attendance.check_in_time) == today
        )
    ).first()
    
    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Anda belum check-in hari ini"
        )
    
    if attendance.check_out_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Anda sudah check-out hari ini"
        )
    
    # Check if it's time to check out
    now = get_jakarta_time()
    if now < attendance.required_checkout_time:
        diff = attendance.required_checkout_time - now
        hours = int(diff.total_seconds() // 3600)
        minutes = int((diff.total_seconds() % 3600) // 60)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Belum waktunya check-out. Anda bisa check-out dalam {hours} jam {minutes} menit"
        )
    
    # Validate location
    is_valid, location_name = LocationService.validate_location(latitude, longitude)
    if not is_valid:
        nearest = LocationService.get_nearest_location(latitude, longitude)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Lokasi Anda tidak valid untuk check-out. Lokasi terdekat: {nearest['name']} ({nearest['distance']} km)"
        )
    
    # Save photo
    photo_filename = save_photo(photo)
    
    # Update attendance
    attendance.check_out_time = now
    attendance.check_out_latitude = latitude
    attendance.check_out_longitude = longitude
    attendance.check_out_location = location_name
    attendance.check_out_photo_url = photo_filename
    
    db.commit()
    db.refresh(attendance)
    
    return AttendanceResponse.model_validate(attendance)

@router.get("/today", response_model=Optional[AttendanceResponse])
def get_today_attendance(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get today's attendance"""
    today = get_jakarta_time().date()
    attendance = db.query(Attendance).filter(
        and_(
            Attendance.user_id == current_user.id,
            func.date(Attendance.check_in_time) == today
        )
    ).first()
    
    if not attendance:
        return None
    
    return AttendanceResponse.model_validate(attendance)

@router.get("/history", response_model=AttendanceHistory)
def get_attendance_history(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    page: int = 1,
    page_size: int = 30,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get attendance history"""
    query = db.query(Attendance).filter(Attendance.user_id == current_user.id)
    
    if start_date:
        start = datetime.fromisoformat(start_date)
        query = query.filter(Attendance.check_in_time >= start)
    
    if end_date:
        end = datetime.fromisoformat(end_date)
        query = query.filter(Attendance.check_in_time <= end)
    
    total = query.count()
    attendances = query.order_by(Attendance.check_in_time.desc()) \
        .offset((page - 1) * page_size) \
        .limit(page_size) \
        .all()
    
    return AttendanceHistory(
        data=[AttendanceResponse.model_validate(a) for a in attendances],
        total=total,
        page=page,
        page_size=page_size
    )

@router.post("/admin/auto-checkout")
def manual_auto_checkout(
    target_date: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Manually trigger auto-checkout for users who forgot to check out.
    Admin only endpoint.
    If target_date is not provided, uses yesterday's date.
    Format: YYYY-MM-DD
    """
    # Check if user is admin (you can add role checking here)
    # For now, any authenticated user can trigger this
    
    if target_date:
        try:
            target = datetime.strptime(target_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD"
            )
    else:
        # Default to yesterday
        target = date.today() - timedelta(days=1)
    
    # Don't allow future dates
    if target > date.today():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot auto-checkout for future dates"
        )
    
    result = AutoCheckoutService.manual_auto_checkout_for_date(target)
    
    if "error" in result:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result["error"]
        )
    
    return {
        "message": f"Auto-checkout completed for {result['date']}",
        "processed_count": result["processed"]
    }

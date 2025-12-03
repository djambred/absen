from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas import AttendanceResponse, AttendanceHistory
from app.models import Attendance
from app.services import LocationService
from app.middleware.auth_middleware import get_current_user
from datetime import datetime, time
import os

router = APIRouter()

def calculate_required_checkout(check_in_time: datetime) -> datetime:
    """Calculate required checkout time based on check-in rules"""
    check_in_hour_minute = check_in_time.time()
    
    # Rule 1: Check-in ≤ 7:30 → checkout at 17:00
    if check_in_hour_minute <= time(7, 30):
        return check_in_time.replace(hour=17, minute=0, second=0, microsecond=0)
    
    # Rule 2: Check-in 8:00-10:00 → checkout at 19:00
    elif time(8, 0) <= check_in_hour_minute <= time(10, 0):
        return check_in_time.replace(hour=19, minute=0, second=0, microsecond=0)
    
    # Rule 3: Check-in > 10:00 → rejected
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Check-in hanya diperbolehkan sampai jam 10:00"
        )

@router.post("/check-in", response_model=AttendanceResponse, status_code=status.HTTP_201_CREATED)
async def check_in(
    latitude: float = Form(...),
    longitude: float = Form(...),
    location: str = Form(...),
    photo: UploadFile = File(...),
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check-in with GPS validation and time rules"""
    # Validate location
    location_check = LocationService.validate_location(latitude, longitude)
    
    if not location_check['valid']:
        # Get nearest location
        nearest = LocationService.get_nearest_location(latitude, longitude)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Lokasi tidak valid. Lokasi terdekat: {nearest['name']} ({nearest['distance']:.0f}m)"
        )
    
    # Calculate required checkout time
    now = datetime.now()
    required_checkout = calculate_required_checkout(now)
    
    # Save photo with user folder and formatted filename
    # Format: YYYY-MM-DD_HH-MM-SS_DayName_checkin.jpg
    day_name = now.strftime('%A')  # Monday, Tuesday, etc
    photo_filename = now.strftime(f'%Y-%m-%d_%H-%M-%S_{day_name}_checkin.jpg')
    user_photo_dir = os.path.join("uploads", "photos", str(current_user.id))
    os.makedirs(user_photo_dir, exist_ok=True)
    photo_path = os.path.join(user_photo_dir, photo_filename)
    
    with open(photo_path, "wb") as f:
        f.write(await photo.read())
    
    # Create attendance record
    attendance = Attendance(
        user_id=current_user.id,
        check_in_time=now,
        check_in_latitude=latitude,
        check_in_longitude=longitude,
        check_in_location=location_check['location'],
        check_in_photo_url=photo_path,
        required_checkout_time=required_checkout,
        status="checked_in"
    )
    
    db.add(attendance)
    db.commit()
    db.refresh(attendance)
    
    return attendance

@router.post("/check-out", response_model=AttendanceResponse)
async def check_out(
    latitude: float = Form(...),
    longitude: float = Form(...),
    location: str = Form(...),
    photo: UploadFile = File(...),
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check-out with GPS validation"""
    # Get today's attendance
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    attendance = db.query(Attendance).filter(
        Attendance.user_id == current_user.id,
        Attendance.check_in_time >= today_start,
        Attendance.check_out_time == None
    ).first()
    
    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tidak ada check-in hari ini"
        )
    
    # Validate location
    location_check = LocationService.validate_location(latitude, longitude)
    
    if not location_check['valid']:
        nearest = LocationService.get_nearest_location(latitude, longitude)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Lokasi tidak valid. Lokasi terdekat: {nearest['name']} ({nearest['distance']:.0f}m)"
        )
    
    # Save photo with user folder and formatted filename
    now = datetime.now()
    # Format: YYYY-MM-DD_HH-MM-SS_DayName_checkout.jpg
    day_name = now.strftime('%A')  # Monday, Tuesday, etc
    photo_filename = now.strftime(f'%Y-%m-%d_%H-%M-%SS_{day_name}_checkout.jpg')
    user_photo_dir = os.path.join("uploads", "photos", str(current_user.id))
    os.makedirs(user_photo_dir, exist_ok=True)
    photo_path = os.path.join(user_photo_dir, photo_filename)
    
    with open(photo_path, "wb") as f:
        f.write(await photo.read())
    
    # Update attendance
    attendance.check_out_time = now
    attendance.check_out_latitude = latitude
    attendance.check_out_longitude = longitude
    attendance.check_out_location = location_check['location']
    attendance.check_out_photo_url = photo_path
    attendance.status = "checked_out"
    
    db.commit()
    db.refresh(attendance)
    
    return attendance

@router.get("/today", response_model=AttendanceResponse)
def get_today_attendance(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get today's attendance"""
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    attendance = db.query(Attendance).filter(
        Attendance.user_id == current_user.id,
        Attendance.check_in_time >= today_start
    ).first()
    
    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Belum ada absensi hari ini"
        )
    
    return attendance

@router.get("/history")
def get_attendance_history(
    limit: int = 30,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get attendance history"""
    attendances = db.query(Attendance).filter(
        Attendance.user_id == current_user.id
    ).order_by(Attendance.check_in_time.desc()).limit(limit).all()
    
    return {"data": attendances}
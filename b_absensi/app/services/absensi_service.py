from sqlalchemy.orm import Session
from sqlalchemy import and_
from datetime import datetime, date
from fastapi import HTTPException, status
from app.models import Absensi
from app.schemas import AbsensiCreate
from app.utils import validate_location
from app.config import LOKASI_ABSENSI

class AbsensiService:
    @staticmethod
    def create_absensi(db: Session, user_id: int, absensi_data: AbsensiCreate) -> Absensi:
        """Create absensi baru dengan validasi lokasi"""
        # Validasi lokasi
        is_valid, location_name = validate_location(
            absensi_data.latitude,
            absensi_data.longitude
        )
        
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Lokasi Anda berada di luar jangkauan lokasi absensi yang diizinkan"
            )
        
        # Cek apakah user sudah absen masuk hari ini
        today = date.today()
        today_start = datetime.combine(today, datetime.min.time())
        today_end = datetime.combine(today, datetime.max.time())
        
        if absensi_data.tipe == "masuk":
            existing = db.query(Absensi).filter(
                and_(
                    Absensi.user_id == user_id,
                    Absensi.tipe == "masuk",
                    Absensi.waktu >= today_start,
                    Absensi.waktu <= today_end
                )
            ).first()
            
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Anda sudah melakukan absen masuk hari ini"
                )
        
        # Create absensi record
        new_absensi = Absensi(
            user_id=user_id,
            tipe=absensi_data.tipe,
            lokasi=location_name or absensi_data.lokasi,
            latitude=absensi_data.latitude,
            longitude=absensi_data.longitude
        )
        
        db.add(new_absensi)
        db.commit()
        db.refresh(new_absensi)
        
        return new_absensi
    
    @staticmethod
    def get_absensi_today(db: Session, user_id: int) -> list:
        """Get absensi untuk hari ini"""
        today = date.today()
        today_start = datetime.combine(today, datetime.min.time())
        today_end = datetime.combine(today, datetime.max.time())
        
        absensi = db.query(Absensi).filter(
            and_(
                Absensi.user_id == user_id,
                Absensi.waktu >= today_start,
                Absensi.waktu <= today_end
            )
        ).order_by(Absensi.waktu.asc()).all()
        
        return absensi
    
    @staticmethod
    def get_absensi_history(db: Session, user_id: int, limit: int = 30) -> list:
        """Get riwayat absensi"""
        absensi = db.query(Absensi).filter(
            Absensi.user_id == user_id
        ).order_by(Absensi.waktu.desc()).limit(limit).all()
        
        return absensi
    
    @staticmethod
    def get_lokasi_list() -> dict:
        """Get list lokasi absensi yang tersedia"""
        return LOKASI_ABSENSI
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models import User
from app.schemas import UserRegister, UserResponse
from app.utils import hash_password, verify_password, create_access_token, create_refresh_token

class AuthService:
    @staticmethod
    def register(db: Session, user_data: UserRegister) -> User:
        """Register user baru"""
        # Check apakah email sudah terdaftar
        existing_user = db.query(User).filter(User.email == user_data.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email sudah terdaftar"
            )
        
        # Create user baru
        hashed_password = hash_password(user_data.password)
        new_user = User(
            email=user_data.email,
            password_hash=hashed_password,
            name=user_data.name,
            nip=user_data.nip,
            role=user_data.role,
            department=user_data.department
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        return new_user
    
    @staticmethod
    def login(db: Session, email: str, password: str) -> dict:
        """Login user"""
        user = db.query(User).filter(User.email == email).first()
        
        if not user or not verify_password(password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email atau password salah"
            )
        
        # Create JWT token
        access_token = create_access_token({"sub": user.id})
        refresh_token = create_refresh_token({"sub": user.id})
        
        # Get primary position or first position
        primary_position = None
        if user.positions:
            # Try to find primary position
            for pos in user.positions:
                primary_position = pos
                break
        
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "email": user.email,
                "name": user.name,
                "nip": user.nip,
                "role": primary_position.code if primary_position else "STAFF",
                "department": user.department,
                "is_active": user.is_active,
                "created_at": user.created_at
            }
        }
    
    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> User:
        """Get user by ID"""
        user = db.query(User).filter(User.id == user_id).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User tidak ditemukan"
            )
        
        return user
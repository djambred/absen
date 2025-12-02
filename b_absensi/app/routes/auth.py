from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas import UserRegister, UserLogin, UserResponse, LoginResponse
from app.services import AuthService
from app.utils import verify_token

router = APIRouter()

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """
    Register user baru
    
    - **email**: Email user yang unik
    - **password**: Password minimal 6 karakter
    - **nama**: Nama lengkap user
    - **departemen**: Departemen user
    """
    new_user = AuthService.register(db, user_data)
    return new_user

@router.post("/login", response_model=LoginResponse)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """
    Login user dan dapatkan JWT token
    
    - **email**: Email user
    - **password**: Password user
    """
    result = AuthService.login(db, credentials.email, credentials.password)
    return result

@router.get("/profile", response_model=UserResponse)
def get_profile(token: str = None, db: Session = Depends(get_db)):
    """
    Get profil user yang sedang login
    
    Header: Authorization: Bearer {token}
    """
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak ditemukan di header"
        )
    
    user_id = verify_token(token)
    user = AuthService.get_user_by_id(db, user_id)
    return user
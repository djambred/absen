from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime

class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)
    name: str
    nip: str
    department: Optional[str] = None
    role: str = "staff"  # dosen, karyawan, staff

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserPinLogin(BaseModel):
    user_id: str
    pin: str = Field(..., min_length=6, max_length=6)

class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    nip: str
    role: str
    department: Optional[str] = None
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserResponse

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class UserPinUpdate(BaseModel):
    pin: str = Field(..., min_length=6, max_length=6)

class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    department: Optional[str] = None

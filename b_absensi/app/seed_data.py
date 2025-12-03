"""
Script untuk membuat sample users saat aplikasi pertama kali dijalankan
"""
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models import User
from app.utils import hash_password
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SAMPLE_USERS = [
    {
        "email": "jefry@mncu.ac.id",
        "password": "password",
        "name": "Jefry",
        "nip": "J001",
        "role": "dosen",
        "department": "Fakultas Ilmu Komputer"
    },
    {
        "email": "dosen@mncu.ac.id",
        "password": "password123",
        "name": "Dr. Ahmad Dosen",
        "nip": "D001",
        "role": "dosen",
        "department": "Fakultas Teknik"
    },
    {
        "email": "karyawan@mncu.ac.id",
        "password": "password123",
        "name": "Budi Karyawan",
        "nip": "K001",
        "role": "karyawan",
        "department": "IT Department"
    },
    {
        "email": "staff@mncu.ac.id",
        "password": "password123",
        "name": "Siti Staff",
        "nip": "S001",
        "role": "staff",
        "department": "HR Department"
    },
    {
        "email": "admin@mncu.ac.id",
        "password": "admin123",
        "name": "Admin MNC",
        "nip": "A001",
        "role": "staff",
        "department": "Administration"
    }
]

def create_sample_users():
    """Create sample users if they don't exist"""
    db = SessionLocal()
    try:
        # Check if users already exist
        existing_users = db.query(User).count()
        if existing_users > 0:
            logger.info(f"Database already has {existing_users} users. Skipping seed data.")
            return
        
        logger.info("Creating sample users...")
        for user_data in SAMPLE_USERS:
            # Check if user with this email already exists
            existing = db.query(User).filter(User.email == user_data["email"]).first()
            if existing:
                logger.info(f"User {user_data['email']} already exists. Skipping.")
                continue
            
            # Create new user
            new_user = User(
                email=user_data["email"],
                password_hash=hash_password(user_data["password"]),
                name=user_data["name"],
                nip=user_data["nip"],
                role=user_data["role"],
                department=user_data["department"],
                is_active=True
            )
            db.add(new_user)
            logger.info(f"Created user: {user_data['email']} ({user_data['role']})")
        
        db.commit()
        logger.info("✅ Sample users created successfully!")
        logger.info("\n" + "="*60)
        logger.info("SAMPLE USER CREDENTIALS:")
        logger.info("="*60)
        for user in SAMPLE_USERS:
            logger.info(f"Email: {user['email']:<20} | Password: {user['password']:<15} | Role: {user['role']}")
        logger.info("="*60 + "\n")
        
    except Exception as e:
        logger.error(f"Error creating sample users: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    # Create tables first
    Base.metadata.create_all(bind=engine)
    # Then create sample users
    create_sample_users()

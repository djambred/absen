"""
Script untuk membuat sample users dan positions saat aplikasi pertama kali dijalankan
"""
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models import User, Position
from app.models.user import user_positions
from app.utils import hash_password
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_positions():
    """Create initial positions/jabatan"""
    db = SessionLocal()
    try:
        # Check if positions already exist
        existing = db.query(Position).count()
        if existing > 0:
            logger.info(f"Positions already exist ({existing} found), skipping creation")
            return
        
        positions_data = [
            # AKADEMIK - Jabatan Akademik
            {"code": "DOSEN", "name": "Dosen", "category": "akademik", "department": "Akademik", "level": 1},
            {"code": "DOSEN_SENIOR", "name": "Dosen Senior", "category": "akademik", "department": "Akademik", "level": 2},
            {"code": "KEPALA_PRODI", "name": "Kepala Program Studi", "category": "akademik", "department": "Akademik", "level": 3},
            {"code": "DEKAN", "name": "Dekan Fakultas", "category": "akademik", "department": "Akademik", "level": 4},
            {"code": "ASISTEN_DOSEN", "name": "Asisten Dosen", "category": "akademik", "department": "Akademik", "level": 1},
            
            # NON-AKADEMIK - IT Department
            {"code": "STAFF_IT", "name": "Staff IT", "category": "non_akademik", "department": "IT", "level": 1},
            {"code": "KEPALA_IT", "name": "Kepala IT", "category": "non_akademik", "department": "IT", "level": 2},
            
            # NON-AKADEMIK - HR Department
            {"code": "STAFF_HR", "name": "Staff HR", "category": "non_akademik", "department": "HR", "level": 1},
            {"code": "KEPALA_HR", "name": "Kepala HR", "category": "non_akademik", "department": "HR", "level": 2},
            
            # NON-AKADEMIK - Finance Department
            {"code": "STAFF_KEUANGAN", "name": "Staff Keuangan", "category": "non_akademik", "department": "Keuangan", "level": 1},
            {"code": "KEPALA_KEUANGAN", "name": "Kepala Keuangan", "category": "non_akademik", "department": "Keuangan", "level": 2},
            
            # NON-AKADEMIK - Administration
            {"code": "STAFF_ADMIN", "name": "Staff Administrasi", "category": "non_akademik", "department": "Administrasi", "level": 1},
            {"code": "KEPALA_ADMIN", "name": "Kepala Administrasi", "category": "non_akademik", "department": "Administrasi", "level": 2},
            
            # NON-AKADEMIK - Library
            {"code": "STAFF_PERPUSTAKAAN", "name": "Staff Perpustakaan", "category": "non_akademik", "department": "Perpustakaan", "level": 1},
            {"code": "KEPALA_PERPUSTAKAAN", "name": "Kepala Perpustakaan", "category": "non_akademik", "department": "Perpustakaan", "level": 2},
        ]
        
        created_positions = {}
        for pos_data in positions_data:
            position = Position(**pos_data)
            db.add(position)
            db.flush()
            created_positions[pos_data["code"]] = position
            logger.info(f"Created position: {pos_data['name']}")
        
        # Set approver relationships
        # Akademik hierarchy
        created_positions["DOSEN"].approver_position_id = created_positions["KEPALA_PRODI"].id
        created_positions["ASISTEN_DOSEN"].approver_position_id = created_positions["DOSEN_SENIOR"].id
        created_positions["DOSEN_SENIOR"].approver_position_id = created_positions["KEPALA_PRODI"].id
        created_positions["KEPALA_PRODI"].approver_position_id = created_positions["DEKAN"].id
        
        # Non-akademik hierarchy - Staff positions report to their respective kepala
        created_positions["STAFF_IT"].approver_position_id = created_positions["KEPALA_IT"].id
        created_positions["STAFF_HR"].approver_position_id = created_positions["KEPALA_HR"].id
        created_positions["STAFF_KEUANGAN"].approver_position_id = created_positions["KEPALA_KEUANGAN"].id
        created_positions["STAFF_ADMIN"].approver_position_id = created_positions["KEPALA_ADMIN"].id
        created_positions["STAFF_PERPUSTAKAAN"].approver_position_id = created_positions["KEPALA_PERPUSTAKAAN"].id
        
        db.commit()
        logger.info(f"Successfully created {len(positions_data)} positions")
        
    except Exception as e:
        logger.error(f"Error creating positions: {e}")
        db.rollback()
    finally:
        db.close()

SAMPLE_USERS = [
    {
        "email": "jefry.sunupurwa@mncu.ac.id",
        "password": "password",
        "name": "Jefry",
        "nip": "J001",
        "department": "Fakultas Ilmu Komputer",
        "positions": ["DOSEN", "STAFF_IT"]  # Double job: Akademik (Dosen) + Non-Akademik (Staff IT)
    },
    {
        "email": "eko.amri.jaya@mncu.ac.id",
        "password": "password123",
        "name": "Eko Amri Jaya",
        "nip": "D001",
        "department": "Fakultas Teknik",
        "positions": ["DOSEN"]  # Akademik only
    },
    {
        "email": "siti@mncu.ac.id",
        "password": "password123",
        "name": "Prof. Siti Nurhaliza",
        "nip": "D002",
        "department": "Fakultas Ekonomi",
        "positions": ["KEPALA_PRODI"]  # Akademik - Kepala Prodi
    },
    {
        "email": "kepala.it@mncu.ac.id",
        "password": "password123",
        "name": "Andi Wijaya",
        "nip": "K001",
        "department": "IT Department",
        "positions": ["KEPALA_IT", "DOSEN"]  # Double job: Non-Akademik (Kepala IT) + Akademik (Dosen)
    },
    {
        "email": "hr@mncu.ac.id",
        "password": "password123",
        "name": "Dewi Lestari",
        "nip": "H001",
        "department": "HR Department",
        "positions": ["KEPALA_HR"]  # Non-Akademik only
    },
    {
        "email": "staff.it@mncu.ac.id",
        "password": "password123",
        "name": "Budi Santoso",
        "nip": "S001",
        "department": "IT Department",
        "positions": ["STAFF_IT"]  # Non-Akademik only
    },
    {
        "email": "staff.hr@mncu.ac.id",
        "password": "password123",
        "name": "Linda Wijayanti",
        "nip": "H002",
        "department": "HR Department",
        "positions": ["STAFF_HR"]  # Non-Akademik only
    },
    {
        "email": "dekan@mncu.ac.id",
        "password": "password123",
        "name": "Prof. Dr. Bambang Hermanto",
        "nip": "D003",
        "department": "Fakultas Teknik",
        "positions": ["DEKAN"]  # Akademik - Dekan
    },
    {
        "email": "admin@mncu.ac.id",
        "password": "admin123",
        "name": "Admin MNC",
        "nip": "A001",
        "department": "Administration",
        "positions": ["STAFF_ADMIN"]  # Non-Akademik only
    }
]

def create_sample_users():
    """Create sample users with positions if they don't exist"""
    db = SessionLocal()
    try:
        # Check if users already exist
        existing_users = db.query(User).count()
        if existing_users > 0:
            logger.info(f"Database already has {existing_users} users. Skipping seed data.")
            return
        
        logger.info("Creating sample users...")
        
        # Get all positions
        positions_dict = {}
        all_positions = db.query(Position).all()
        for pos in all_positions:
            positions_dict[pos.code] = pos
        
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
                department=user_data["department"],
                is_active=True
            )
            db.add(new_user)
            db.flush()  # Flush to get user ID
            
            # Assign positions to user
            if "positions" in user_data:
                for idx, pos_code in enumerate(user_data["positions"]):
                    if pos_code in positions_dict:
                        position = positions_dict[pos_code]
                        # Insert into association table
                        stmt = user_positions.insert().values(
                            user_id=new_user.id,
                            position_id=position.id,
                            is_primary=(idx == 0)  # First position is primary
                        )
                        db.execute(stmt)
                        logger.info(f"  - Assigned position: {position.name} (primary: {idx == 0})")
            
            logger.info(f"Created user: {user_data['email']}")
        
        db.commit()
        logger.info("✅ Sample users created successfully!")
        logger.info("\n" + "="*60)
        logger.info("SAMPLE USER CREDENTIALS:")
        logger.info("="*60)
        for user in SAMPLE_USERS:
            positions_str = ", ".join(user.get("positions", []))
            logger.info(f"Email: {user['email']:<25} | Password: {user['password']:<15} | Positions: {positions_str}")
        logger.info("="*60 + "\n")
        
    except Exception as e:
        logger.error(f"Error creating sample users: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    # Create tables first
    Base.metadata.create_all(bind=engine)
    # Create positions
    create_positions()
    # Then create sample users
    create_sample_users()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.database import Base, engine
from app.routes import auth, attendance, leave, task
from app.scheduler import start_scheduler, stop_scheduler
from sqlalchemy import text

# Import models to ensure they are registered with SQLAlchemy
from app.models import User, Attendance, Leave, Position, LeaveQuota, Task

# Create tables
Base.metadata.create_all(bind=engine)

# Run migrations
def run_migrations():
    """Run database migrations"""
    with engine.connect() as conn:
        # Add supervisor_id column if it doesn't exist
        try:
            conn.execute(text("""
                ALTER TABLE leaves ADD COLUMN supervisor_id VARCHAR(36);
            """))
            conn.commit()
        except Exception as e:
            # Column might already exist
            pass
        
        # Add foreign key constraint
        try:
            conn.execute(text("""
                ALTER TABLE leaves ADD CONSTRAINT fk_leaves_supervisor_id
                FOREIGN KEY (supervisor_id) REFERENCES users(id);
            """))
            conn.commit()
        except Exception as e:
            # Constraint might already exist
            pass
        
        # Create index for better performance
        try:
            conn.execute(text("""
                CREATE INDEX idx_leaves_supervisor_id ON leaves(supervisor_id);
            """))
            conn.commit()
        except Exception as e:
            # Index might already exist
            pass

run_migrations()

# Import and create sample data after tables are created
from app.seed_data import create_positions, create_sample_users
create_positions()
create_sample_users()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start the scheduler
    start_scheduler()
    yield
    # Shutdown: Stop the scheduler
    stop_scheduler()

app = FastAPI(
    title="Aplikasi Absensi API",
    description="API untuk sistem absensi dengan GPS validation",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(attendance.router, prefix="/api/attendance", tags=["Attendance"])
app.include_router(leave.router, prefix="/api/leave", tags=["Leave"])
app.include_router(task.router, prefix="/api/tasks", tags=["Tasks"])

@app.get("/")
def read_root():
    return {"message": "Selamat datang di API Absensi"}

@app.get("/health")
def health_check():
    return {"status": "API is running", "version": "1.0.0"}
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import Base, engine
from app.routes import auth, absensi
from app.seed_data import create_sample_users

# Create tables
Base.metadata.create_all(bind=engine)

# Create sample users on startup
create_sample_users()

app = FastAPI(
    title="Aplikasi Absensi API",
    description="API untuk sistem absensi dengan GPS validation",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(absensi.router, prefix="/api/absensi", tags=["Absensi"])

@app.get("/")
def read_root():
    return {"message": "Selamat datang di API Absensi"}

@app.get("/health")
def health_check():
    return {"status": "API is running", "version": "1.0.0"}
import os
from dotenv import load_dotenv
import pytz

load_dotenv()

# Timezone Configuration
TIMEZONE = "Asia/Jakarta"
TZ = pytz.timezone(TIMEZONE)

# Database Configuration
DATABASE_USER = os.getenv("DATABASE_USER", "root")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD", "password")
DATABASE_HOST = os.getenv("DATABASE_HOST", "localhost")
DATABASE_PORT = os.getenv("DATABASE_PORT", "3306")
DATABASE_NAME = os.getenv("DATABASE_NAME", "absensi_db")

DATABASE_URL = f"mysql+pymysql://{DATABASE_USER}:{DATABASE_PASSWORD}@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_NAME}"

# Security Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 7

# Lokasi Absensi
LOKASI_ABSENSI = {
    "MNC Tower": {
        "lat": -6.1840816,
        "lon": 106.8266783,
        "radius": 0.5,  # dalam km
        "address": "Jl. Kebon Sirih No.Kav. 17-19 RT.15/RW.7, Kb. Sirih Kec. Menteng, Kota, Daerah Khusus Ibukota Jakarta 10340"
    },
    "iNews Tower": {
        "lat": -6.1849557,
        "lon": 106.8292002,
        "radius": 0.5,
        "address": "Jl. K.H. Wahid Hasyim No.36-38, RT.15/RW.7, Kb. Sirih, Kec. Menteng, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10340"
    },
    "MNC University": {
        "lat": -6.1641491,
        "lon": 106.7601071,
        "radius": 0.5,
        "address": "Jl. Panjang Blok A8, Jl. Green Garden Pintu Utara Prov. D.K.I, RT.1/RW.3, North Kedoya, Kebonjeruk, West Jakarta City, Jakarta 11520"
    }
}

# App Configuration
APP_HOST = os.getenv("APP_HOST", "0.0.0.0")
APP_PORT = int(os.getenv("APP_PORT", "8000"))
APP_ENV = os.getenv("APP_ENV", "development")

# File Upload Configuration
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")

# Settings class for compatibility
class Settings:
    DATABASE_URL = DATABASE_URL
    SECRET_KEY = SECRET_KEY
    ALGORITHM = ALGORITHM
    ACCESS_TOKEN_EXPIRE_DAYS = ACCESS_TOKEN_EXPIRE_DAYS
    LOKASI_ABSENSI = LOKASI_ABSENSI
    TIMEZONE = TIMEZONE
    TZ = TZ
    APP_HOST = APP_HOST
    APP_PORT = APP_PORT
    APP_ENV = APP_ENV
    UPLOAD_DIR = UPLOAD_DIR

settings = Settings()
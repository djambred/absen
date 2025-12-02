# Aplikasi Absensi API

API untuk sistem absensi dengan GPS validation untuk dosen, karyawan, dan staff MNC.

## Features

- ✅ Check-in/Check-out dengan GPS validation
- ✅ Upload foto selfie saat absensi
- ✅ Time-based checkout rules:
  - Check-in ≤ 7:30 → checkout at 17:00
  - Check-in 8:00-10:00 → checkout at 19:00
  - Check-in > 10:00 → rejected
- ✅ Validasi lokasi (3 lokasi MNC dengan radius 100m)
- ✅ Suggest nearest location jika di luar radius
- ✅ JWT Authentication
- ✅ Auto-create sample users

## Quick Start

### 1. Start with Docker Compose

```bash
cd b_absensi
docker compose up -d
```

### 2. Check Status

```bash
docker ps
docker logs absensi_api
```

### 3. Test API

```bash
# Health check
curl http://localhost:8000/health

# Login with sample user
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "staff@mnc.id", "password": "password123"}'
```

## Sample Users

Sample users dibuat otomatis saat pertama kali menjalankan docker compose:

| Email | Password | Role | NIP | Department |
|-------|----------|------|-----|------------|
| dosen@mnc.id | password123 | dosen | D001 | Fakultas Teknik |
| karyawan@mnc.id | password123 | karyawan | K001 | IT Department |
| staff@mnc.id | password123 | staff | S001 | HR Department |
| admin@mnc.id | admin123 | staff | A001 | Administration |

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register user baru
- `POST /api/auth/login` - Login dan dapatkan JWT token
- `GET /api/auth/profile` - Get profil user (requires token)

### Attendance
- `POST /api/absensi/check-in` - Check-in dengan GPS & foto
- `POST /api/absensi/check-out` - Check-out dengan GPS & foto
- `GET /api/absensi/today` - Get absensi hari ini
- `GET /api/absensi/history?limit=30` - Get riwayat absensi

## Valid Locations

1. **iNews Tower**
   - Latitude: -6.184961
   - Longitude: 106.8317751
   - Radius: 100m

2. **MNC Tower**
   - Latitude: -6.184087
   - Longitude: 106.8315492
   - Radius: 100m

3. **MNC University**
   - Latitude: -6.1641544
   - Longitude: 106.762682
   - Radius: 100m

## Environment Variables

Create `.env` file:

```env
# Database
DATABASE_URL=mysql+pymysql://absensi_user:absensi123@db:3306/absensi_db

# JWT
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# App
APP_NAME=Absensi API
APP_VERSION=1.0.0
```

## Docker Commands

```bash
# Start containers
docker compose up -d

# Stop containers
docker compose down

# View logs
docker logs absensi_api
docker logs absensi_mysql

# Restart API
docker restart absensi_api

# Reset database (drops all data)
docker exec -it absensi_mysql mariadb -uroot -ppassword -e "DROP DATABASE IF EXISTS absensi_db; CREATE DATABASE absensi_db;"
docker restart absensi_api
```

## Development

### Run without Docker

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export DATABASE_URL=mysql+pymysql://user:pass@localhost:3306/absensi_db

# Run server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Tech Stack

- **Framework**: FastAPI
- **Database**: MariaDB
- **ORM**: SQLAlchemy
- **Authentication**: JWT (python-jose)
- **Password Hashing**: bcrypt (passlib)
- **Server**: Uvicorn
- **Containerization**: Docker & Docker Compose

## Project Structure

```
b_absensi/
├── app/
│   ├── models/          # Database models
│   ├── schemas/         # Pydantic schemas
│   ├── routes/          # API routes
│   ├── services/        # Business logic
│   ├── middleware/      # Auth middleware
│   ├── utils/           # Utilities (security, constants)
│   ├── database.py      # Database connection
│   ├── config.py        # App configuration
│   └── seed_data.py     # Sample data seeder
├── uploads/             # Uploaded photos
├── main.py              # App entry point
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── README.md
```

## API Documentation

Once the server is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

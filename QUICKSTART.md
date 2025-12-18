# 🚀 TCS Quick Start Guide

## Prerequisites Check

Before you begin, ensure you have:
- ✅ Python 3.9+ installed
- ✅ Flutter 3.0+ installed
- ✅ PostgreSQL 14+ installed
- ✅ Redis installed (optional for now, needed for chat)
- ✅ Git installed

## Backend Quick Start

### 1. Navigate to Backend
```bash
cd backend
```

### 2. Activate Virtual Environment
```bash
source venv/bin/activate
```

### 3. Install Dependencies (Already done, but in case)
```bash
pip install -r requirements.txt
```

### 4. Setup Database

**Option A: Use PostgreSQL**
```bash
# Create database
createdb tcs_db

# Update .env file with your PostgreSQL credentials
```

**Option B: Use SQLite (for quick testing)**
Edit `config/settings.py` and temporarily change database to SQLite:
```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}
```

### 5. Run Migrations
```bash
python manage.py makemigrations
python manage.py migrate
```

### 6. Create Superuser
```bash
python manage.py createsuperuser
# Follow prompts - use:
# user_id: ADMIN001
# role: teaching_staff
# date_of_birth: 1990-01-01
# password: admin123 (or your choice)
```

### 7. Run Development Server
```bash
python manage.py runserver
```

✅ Backend running at: http://localhost:8000
📊 Admin panel: http://localhost:8000/admin

## Frontend Quick Start

### 1. Open New Terminal & Navigate to Frontend
```bash
cd frontend
```

### 2. Get Flutter Dependencies
```bash
flutter pub get
```

### 3. Run Flutter App

**For Web:**
```bash
flutter run -d chrome
```

**For Android/iOS:**
```bash
flutter run
# Make sure you have an emulator running or device connected
```

**For macOS:**
```bash
flutter run -d macos
```

✅ Frontend running!

## Verify Installation

### Test Backend
Open browser and visit:
- http://localhost:8000/admin - Django admin (login with superuser)
- http://localhost:8000/api/users/ - Should see API root

### Test Frontend
The Flutter app should launch and show the default screen

## Project Structure Overview

```
TCS/
├── backend/          ← Django REST API
│   ├── apps/        ← All Django apps
│   ├── config/      ← Settings
│   └── manage.py    ← Django commands
│
└── frontend/        ← Flutter app
    ├── lib/         ← All Dart code
    ├── assets/      ← Images, icons
    └── pubspec.yaml ← Dependencies
```

## Common Commands Reference

### Backend Commands
```bash
# Activate venv
source venv/bin/activate

# Run server
python manage.py runserver

# Make migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Shell
python manage.py shell

# Run tests
python manage.py test
```

### Frontend Commands
```bash
# Get dependencies
flutter pub get

# Run app
flutter run

# Run on specific device
flutter run -d chrome
flutter run -d macos

# Build release
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web

# Clean build
flutter clean

# Run tests
flutter test

# Check for issues
flutter doctor
```

## Next Development Steps

1. **Week 2 Goal: Authentication**
   - Implement user login endpoints
   - Create login screens in Flutter
   - Test authentication flow

2. **Resources**
   - Backend Guide: `backend/BACKEND_GUIDE.md`
   - Frontend Guide: `frontend/FRONTEND_GUIDE.md`
   - Full Roadmap: `ROADMAP.md`

## Troubleshooting

### Backend Issues

**Database connection error:**
```bash
# Check PostgreSQL is running
pg_isready

# Or use SQLite temporarily (see step 4 above)
```

**Port already in use:**
```bash
# Run on different port
python manage.py runserver 8001
```

### Frontend Issues

**Dependencies error:**
```bash
flutter clean
flutter pub get
```

**No devices available:**
```bash
flutter doctor
# Follow instructions to set up at least one platform
```

## Development Workflow

### Daily Workflow
1. Pull latest changes from git
2. Activate backend venv: `source venv/bin/activate`
3. Start backend: `python manage.py runserver`
4. In new terminal, start frontend: `cd frontend && flutter run`
5. Make changes and test
6. Commit and push changes

### Before Committing
- Run backend tests: `python manage.py test`
- Run frontend tests: `flutter test`
- Check for errors: `flutter analyze`

## Helpful Resources

### Documentation
- Django: https://docs.djangoproject.com/
- DRF: https://www.django-rest-framework.org/
- Flutter: https://flutter.dev/docs
- Flame (games): https://docs.flame-engine.org/

### Project Docs
- [README.md](README.md) - Project overview
- [ROADMAP.md](ROADMAP.md) - Development timeline
- [backend/BACKEND_GUIDE.md](backend/BACKEND_GUIDE.md) - Backend details
- [frontend/FRONTEND_GUIDE.md](frontend/FRONTEND_GUIDE.md) - Frontend details

## Support

### Getting Help
- Check documentation files
- Review error messages carefully
- Search for similar issues online
- Ask team members

---

**🎉 You're all set! Happy coding!**

Current Phase: **Week 1 Complete** ✅
Next Phase: **Week 2 - Authentication System**

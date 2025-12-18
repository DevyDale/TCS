# TCS Quick Reference Card

## 🚀 Start Commands

### Backend
```bash
cd /Users/yigamatthew/Downloads/projects/TCS/backend
source venv/bin/activate
python manage.py runserver
```

### Frontend
```bash
cd /Users/yigamatthew/Downloads/projects/TCS/frontend
flutter run
```

## 📊 Project Stats

- **Total Files**: 150+
- **Django Apps**: 7
- **Models**: 11
- **Documentation Pages**: 8
- **Setup Time**: 15 minutes
- **Lines of Config**: 1000+

## 🔑 Key URLs

- Backend API: http://localhost:8000
- Admin Panel: http://localhost:8000/admin
- API Docs: http://localhost:8000/api/

## 📱 User Roles

| Role | Login Method | Access |
|------|-------------|--------|
| Student | ID + DOB | Full |
| Teaching Staff | ID + DOB | Full + Moderation |
| Non-Teaching Staff | ID + DOB | Limited |
| Parent/Visitor | Email + Password | View-only |

## 🎮 Arcade Games

1. Campus Craft - 2D builder
2. Ninja Tag - Battle arena
3. Sushi Rush - Co-op cooking
4. Battle Bots - Robot battles
5. Spirit Racers - Kart racing
6. Pool Royale - Pool game

## 📦 Tech Stack

**Backend**: Django 6.0 + DRF + JWT + PostgreSQL + Channels
**Frontend**: Flutter + Provider + Dio + Flame
**Storage**: Supabase + Firebase
**AI**: Dale AI

## 📁 Important Files

```
TCS/
├── README.md              # Start here
├── QUICKSTART.md          # Setup guide
├── ROADMAP.md             # 18-week plan
├── ARCHITECTURE.md        # System design
├── PROJECT_STATUS.md      # Current status
├── backend/
│   ├── BACKEND_GUIDE.md   # Backend docs
│   └── apps/              # 7 Django apps
└── frontend/
    ├── FRONTEND_GUIDE.md  # Flutter docs
    └── lib/               # All Dart code
```

## ⚡ Quick Actions

### Create Migration
```bash
python manage.py makemigrations
python manage.py migrate
```

### Create Superuser
```bash
python manage.py createsuperuser
```

### Flutter Get Packages
```bash
flutter pub get
```

### Run Tests
```bash
# Backend
python manage.py test

# Frontend
flutter test
```

## 🐛 Troubleshooting

**Backend won't start**: Check venv activated
**Frontend errors**: Run `flutter clean && flutter pub get`
**Database error**: Run migrations
**Port busy**: Use different port: `python manage.py runserver 8001`

## 📅 Current Phase

**Phase 1, Week 1**: ✅ COMPLETE
**Next**: Week 2 - Authentication System

## 🎯 Week 2 Goals

- [ ] User authentication endpoints
- [ ] Login screens (2 types)
- [ ] Token management
- [ ] Profile API

## 📞 Quick Commands

```bash
# Backend
source backend/venv/bin/activate  # Activate venv
python manage.py shell            # Django shell
python manage.py dbshell          # Database shell

# Frontend  
flutter doctor                    # Check Flutter setup
flutter clean                     # Clean build
flutter run -d chrome             # Run on web
flutter build apk                 # Build Android
```

## 🔒 Security Checklist

- [x] JWT authentication configured
- [x] CORS headers set
- [x] Role-based permissions defined
- [x] Secure storage configured
- [ ] Environment variables set (do this!)
- [ ] Secret key changed (do this!)

## 📊 API Endpoints (Planned)

```
POST   /api/token/                    # Get tokens
POST   /api/token/refresh/            # Refresh token
POST   /api/users/login/              # Login (ID + DOB)
GET    /api/users/me/                 # Current user
GET    /api/posts/                    # List posts
POST   /api/posts/                    # Create post
GET    /api/games/                    # List games
POST   /api/games/{id}/score/         # Submit score
```

## 💾 Database Models

- **User** - Custom auth model
- **Submission** - Self-service registration
- **Post, Like, Comment** - Social features
- **Group, GroupMembership** - Clubs & study groups
- **Game, GameScore, Achievement** - Arcade

## 🎨 Color Scheme (Suggested)

- Primary: Blue (#2196F3)
- Secondary: Orange (#FF9800)
- Success: Green (#4CAF50)
- Warning: Amber (#FFC107)
- Error: Red (#F44336)

## 📱 Screen Flow

```
Splash → Language → Onboarding → Role Selection
  ↓
Login (ID+DOB or Email+Password)
  ↓
Dashboard (Feed, Groups, Events, Arcade, Chat)
```

## ⏱️ Development Time Estimates

- **Authentication**: 1 week
- **Social Feed**: 1 week
- **Groups**: 1 week
- **Chat**: 1 week
- **Each Game**: 1 week
- **AI Integration**: 1 week

**Total MVP**: 8 weeks
**Full Launch**: 18 weeks

---

**Print this and keep on your desk! 📌**

# TCS - Taylors College Social Media & Arcade Platform

A cross-platform social media and arcade platform tailored for Taylors College communities.

## 🎯 Project Overview

TCS combines social networking features with an integrated arcade module, providing students, teaching staff, non-teaching staff, parents, and visitors with a unified platform for engagement and entertainment.

### Key Features
- **Social Networking**: Posts, feeds, clubs, and real-time chat
- **Role-Based Access**: Secure authentication with role-specific permissions
- **Arcade Games**: Mini-games including Campus Craft, Ninja Tag, Sushi Rush Kitchen, Battle Bots, Spirit Racers, and Pool Royale
- **AI-Powered**: Content moderation and personalized recommendations via Dale AI
- **Cross-Platform**: Android, iOS, and Web support

## 📁 Project Structure

```
TCS/
├── backend/                    # Django REST Framework backend
│   ├── venv/                  # Python virtual environment
│   ├── config/                # Django project settings
│   ├── apps/                  # Django applications
│   │   ├── users/            # User management & authentication
│   │   ├── submissions/      # Self-service data entry
│   │   ├── posts/            # Social media posts & feed
│   │   ├── groups/           # Study groups & clubs
│   │   ├── chat/             # Real-time messaging
│   │   ├── games/            # Arcade games & leaderboards
│   │   └── ai/               # Dale AI integration
│   ├── requirements.txt       # Python dependencies
│   ├── .env                   # Environment variables
│   └── manage.py             # Django management script
│
└── frontend/                  # Flutter application
    ├── lib/
    │   ├── models/           # Data models
    │   ├── services/         # API & business logic
    │   ├── screens/          # UI screens
    │   ├── widgets/          # Reusable components
    │   ├── utils/            # Helper functions
    │   └── config/           # App configuration
    ├── assets/               # Images, icons, animations
    └── pubspec.yaml          # Flutter dependencies
```

## 🚀 Getting Started

### Prerequisites
- Python 3.9+
- Flutter 3.0+
- PostgreSQL 14+
- Redis (for real-time features)
- Git

### Backend Setup

1. **Navigate to backend directory**
   ```bash
   cd backend
   ```

2. **Activate virtual environment**
   ```bash
   source venv/bin/activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configurations
   ```

5. **Run migrations**
   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```

6. **Create superuser**
   ```bash
   python manage.py createsuperuser
   ```

7. **Run development server**
   ```bash
   python manage.py runserver
   ```

Backend will be available at: `http://localhost:8000`

### Frontend Setup

1. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API endpoints**
   - Edit `lib/config/app_config.dart` with your backend URL

4. **Run the app**
   ```bash
   flutter run
   ```

   Or for web:
   ```bash
   flutter run -d chrome
   ```

## 🔐 User Roles & Authentication

| Role | Login Method | Access Level |
|------|-------------|--------------|
| Student | ID + DOB | Full access (feed, groups, arcade, chat) |
| Teaching Staff | ID + DOB | Full access + content moderation |
| Non-Teaching Staff | ID + DOB | Limited administrative access |
| Parents/Visitors | Email/Username + Password | View-only access |

## 🎮 Arcade Games

1. **Campus Craft** - 2D mini-world builder with social sharing
2. **Ninja Tag** - 1-2 minute battle arena with multiplayer
3. **Sushi Rush Kitchen** - Co-op cooking rounds
4. **Battle Bots** - Drag-and-drop robot battles
5. **Spirit Racers** - 1-minute drift kart races
6. **Pool Royale** - 8/9-ball pool with campus power-ups

## 🛠️ Tech Stack

### Backend
- **Framework**: Django 6.0 + Django REST Framework
- **Database**: PostgreSQL
- **Authentication**: JWT (djangorestframework-simplejwt)
- **Real-time**: Django Channels + Redis
- **File Storage**: Supabase (images) + Firebase (videos)

### Frontend
- **Framework**: Flutter
- **State Management**: Provider + GetX
- **Networking**: Dio
- **Game Engine**: Flame
- **Storage**: Shared Preferences + Secure Storage

### AI & Services
- **AI**: Dale AI for content moderation & recommendations
- **Storage**: Supabase + Firebase
- **Hosting**: Render/Railway (backend), Vercel (frontend)

## 📦 Key Dependencies

### Backend (Python)
```
django==6.0
djangorestframework==3.16.1
djangorestframework-simplejwt==5.5.1
django-cors-headers==4.9.0
psycopg2-binary==2.9.11
pillow==12.0.0
qrcode==8.2
python-decouple==3.8
django-filter==25.2
channels==4.3.2
channels-redis==4.3.0
```

### Frontend (Flutter)
- provider: ^6.1.1
- dio: ^5.4.0
- firebase_core: ^2.24.2
- supabase_flutter: ^2.0.0
- flame: ^1.13.1
- qr_flutter: ^4.1.0
- And more (see pubspec.yaml)

## 🗄️ Database Models

### Core Models
- **User**: Custom user model with role-based fields
- **Submission**: Self-service data entry records
- **Post**: Social media posts with engagement metrics
- **Group**: Study groups and clubs
- **Game**: Arcade game definitions
- **GameScore**: Leaderboard entries
- **Achievement**: Game achievements

## 🔄 API Endpoints

### Authentication
- `POST /api/token/` - Get JWT tokens
- `POST /api/token/refresh/` - Refresh access token

### Users
- `POST /api/users/login/` - Login with ID + DOB
- `GET /api/users/me/` - Get current user
- `PUT /api/users/me/` - Update profile

### Posts
- `GET /api/posts/` - List posts (feed)
- `POST /api/posts/` - Create post
- `POST /api/posts/{id}/like/` - Like/unlike post

### Games
- `GET /api/games/` - List available games
- `POST /api/games/{id}/score/` - Submit game score
- `GET /api/games/{id}/leaderboard/` - Get leaderboard

## 🔒 Security Features

- JWT-based authentication
- Role-based permissions
- Content moderation via AI
- Token verification for submissions
- CORS protection
- Secure storage for sensitive data

## 📱 Development Workflow

### Phase 1 - MVP
- [x] Project setup & structure
- [x] User authentication system
- [x] Basic models & database
- [ ] Self-service data entry panel
- [ ] Social feed & posting
- [ ] First arcade game (Campus Craft)

### Phase 2 - Full Features
- [ ] Remaining arcade games
- [ ] Real-time chat & reactions
- [ ] Leaderboards & achievements
- [ ] AI-powered features
- [ ] Multi-platform testing

## 🧪 Testing

### Backend Tests
```bash
cd backend
source venv/bin/activate
python manage.py test
```

### Frontend Tests
```bash
cd frontend
flutter test
```

## 📝 Environment Variables

Create a `.env` file in the backend directory:

```env
SECRET_KEY=your_secret_key
DEBUG=True
DB_NAME=tcs_db
DB_USER=postgres
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
DALE_AI_API_KEY=your_dale_ai_key
```

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## 📄 License

This project is proprietary to Taylors College.

## 📞 Support

For questions or issues, contact the development team.

---

**Built with ❤️ for Taylors College Community**

# TCS Backend Development Guide

## Overview
The TCS backend is built with Django and Django REST Framework, providing a robust API for the mobile and web applications.

## Architecture

### Apps Structure

#### 1. Users App (`apps/users/`)
**Purpose**: User management and authentication

**Models**:
- `User`: Custom user model with role-based fields

**Key Features**:
- ID + DOB authentication for students/staff
- Username/email + password for parents/visitors
- Role-based permissions
- JWT token management

**Endpoints** (To be implemented):
```
POST /api/users/login/           # Login with ID + DOB
POST /api/users/login-password/  # Login with username/password
GET  /api/users/me/              # Get current user
PUT  /api/users/me/              # Update profile
GET  /api/users/{id}/            # Get user by ID
```

#### 2. Submissions App (`apps/submissions/`)
**Purpose**: Self-service data entry system

**Models**:
- `Submission`: Stores user registration submissions

**Key Features**:
- QR code token validation
- Admin approval workflow
- Verification system

**Endpoints** (To be implemented):
```
POST /api/submissions/           # Submit registration
GET  /api/submissions/pending/   # Admin: view pending
PUT  /api/submissions/{id}/approve/  # Admin: approve
PUT  /api/submissions/{id}/reject/   # Admin: reject
```

#### 3. Posts App (`apps/posts/`)
**Purpose**: Social media feed

**Models**:
- `Post`: Social media posts
- `Like`: Post likes
- `Comment`: Post comments

**Key Features**:
- Text, image, and video posts
- Engagement metrics (likes, comments, shares)
- AI-powered moderation
- Role-based visibility

**Endpoints** (To be implemented):
```
GET  /api/posts/                 # List posts (feed)
POST /api/posts/                 # Create post
GET  /api/posts/{id}/            # Get post detail
PUT  /api/posts/{id}/            # Update post
DELETE /api/posts/{id}/          # Delete post
POST /api/posts/{id}/like/       # Like/unlike post
POST /api/posts/{id}/comment/    # Add comment
```

#### 4. Groups App (`apps/groups/`)
**Purpose**: Study groups and clubs

**Models**:
- `Group`: Group definition
- `GroupMembership`: User-group relationship

**Key Features**:
- Public/private groups
- Member management
- Moderator roles
- Group events

**Endpoints** (To be implemented):
```
GET  /api/groups/                # List groups
POST /api/groups/                # Create group
GET  /api/groups/{id}/           # Get group detail
POST /api/groups/{id}/join/      # Join group
POST /api/groups/{id}/leave/     # Leave group
GET  /api/groups/{id}/members/   # List members
```

#### 5. Chat App (`apps/chat/`)
**Purpose**: Real-time messaging

**Key Features**:
- Direct messages
- Group chats
- Real-time updates via WebSockets
- Message history

**WebSocket Routes** (To be implemented):
```
ws://localhost:8000/ws/chat/{room_id}/
```

#### 6. Games App (`apps/games/`)
**Purpose**: Arcade games and leaderboards

**Models**:
- `Game`: Game definitions
- `GameScore`: Player scores
- `Achievement`: Game achievements
- `UserAchievement`: Unlocked achievements

**Key Features**:
- Leaderboards
- Achievement system
- Game stats tracking
- Replay storage

**Endpoints** (To be implemented):
```
GET  /api/games/                     # List games
GET  /api/games/{id}/                # Get game detail
POST /api/games/{id}/score/          # Submit score
GET  /api/games/{id}/leaderboard/    # Get leaderboard
GET  /api/games/{id}/achievements/   # List achievements
POST /api/games/{id}/achievements/{achievement_id}/unlock/  # Unlock achievement
```

#### 7. AI App (`apps/ai/`)
**Purpose**: Dale AI integration

**Key Features**:
- Content moderation
- Personalized recommendations
- Highlight generation
- Sentiment analysis

**Endpoints** (To be implemented):
```
POST /api/ai/moderate/           # Moderate content
GET  /api/ai/recommendations/    # Get personalized recommendations
POST /api/ai/generate-highlight/ # Generate game highlight
```

## Database Schema

### User Table
```python
- user_id (CharField, unique)
- role (CharField: student, teaching_staff, etc.)
- name (CharField)
- preferred_name (CharField, optional)
- date_of_birth (DateField)
- gender (CharField, optional)
- email (EmailField, optional)
- username (CharField, optional)
- program (CharField, optional)
- electives (TextField, optional)
- subjects_taught (TextField, optional)
- avatar (ImageField, optional)
- bio (TextField, optional)
- is_active (BooleanField)
- is_verified (BooleanField)
- date_joined (DateTimeField)
```

## Authentication Flow

### For Students/Staff (ID + DOB)
1. User submits user_id and date_of_birth
2. Backend verifies credentials against database
3. If valid, generate JWT tokens (access + refresh)
4. Return tokens and user data

### For Parents/Visitors (Username + Password)
1. User submits username/email and password
2. Backend verifies credentials
3. If valid, generate JWT tokens
4. Return tokens and user data

### Token Refresh
1. When access token expires
2. Send refresh token to `/api/token/refresh/`
3. Receive new access token
4. Continue making requests

## Permissions System

### Role Permissions
```python
Student:
  - Can view/create posts
  - Can join groups
  - Can play games
  - Can chat with students & staff

Teaching Staff:
  - All student permissions
  - Can moderate content
  - Can create announcements
  - Can view analytics

Non-Teaching Staff:
  - Limited administrative access
  - Can view/create posts
  - Optional arcade access

Parents/Visitors:
  - View-only for announcements
  - No posting capability
  - No arcade access
```

## Media Storage Strategy

### Supabase (Lightweight Media)
- User avatars
- Group cover images
- Post images
- Game thumbnails

### Firebase (Heavy Media)
- Video posts
- Game replays
- Highlights
- Large files

## Real-time Features (Django Channels)

### WebSocket Consumers
```python
# Chat Consumer
class ChatConsumer(AsyncWebsocketConsumer):
    # Handle real-time chat messages
    
# Feed Consumer  
class FeedConsumer(AsyncWebsocketConsumer):
    # Handle real-time feed updates
    
# Game Consumer
class GameConsumer(AsyncWebsocketConsumer):
    # Handle spectator mode, reactions
```

## API Response Format

### Success Response
```json
{
  "success": true,
  "data": {...},
  "message": "Operation successful"
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error message",
  "details": {...}
}
```

### Paginated Response
```json
{
  "success": true,
  "data": {
    "count": 100,
    "next": "http://api.example.com/posts/?page=2",
    "previous": null,
    "results": [...]
  }
}
```

## Development Commands

### Create migrations
```bash
python manage.py makemigrations
```

### Apply migrations
```bash
python manage.py migrate
```

### Create superuser
```bash
python manage.py createsuperuser
```

### Run server
```bash
python manage.py runserver
```

### Run tests
```bash
python manage.py test
```

### Create admin user for testing
```bash
python manage.py shell
from apps.users.models import User
User.objects.create_superuser(
    user_id='ADMIN001',
    role='teaching_staff',
    date_of_birth='1990-01-01',
    password='admin123',
    name='Admin User'
)
```

## Next Steps

### Immediate Tasks
1. Implement user authentication views and serializers
2. Create submission approval system
3. Build social feed API
4. Set up Django Channels for real-time features
5. Integrate Supabase/Firebase storage
6. Implement Dale AI integration

### Testing
1. Write unit tests for models
2. Create API endpoint tests
3. Test authentication flow
4. Test permissions system
5. Load testing for real-time features

---

**Ready to start development!** 🚀

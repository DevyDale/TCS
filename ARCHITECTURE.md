# TCS System Architecture

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLIENT LAYER                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │   Android    │    │     iOS      │    │     Web      │              │
│  │   Flutter    │    │   Flutter    │    │   Flutter    │              │
│  │     App      │    │     App      │    │     App      │              │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘              │
│         │                   │                    │                       │
│         └───────────────────┴────────────────────┘                       │
│                             │                                            │
└─────────────────────────────┼────────────────────────────────────────────┘
                              │
                              │ HTTPS / WSS
                              │
┌─────────────────────────────┼────────────────────────────────────────────┐
│                             │         API GATEWAY                         │
├─────────────────────────────┼────────────────────────────────────────────┤
│                             ▼                                            │
│              ┌─────────────────────────────┐                             │
│              │   Django REST Framework     │                             │
│              │   + Django Channels         │                             │
│              └──────────┬──────────────────┘                             │
│                         │                                                │
│         ┌───────────────┼───────────────┐                                │
│         │               │               │                                │
│         ▼               ▼               ▼                                │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐                          │
│   │  Users  │     │  Posts  │     │  Games  │                          │
│   │   App   │     │   App   │     │   App   │                          │
│   └─────────┘     └─────────┘     └─────────┘                          │
│                                                                           │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐                          │
│   │Submiss. │     │ Groups  │     │   AI    │                          │
│   │   App   │     │   App   │     │   App   │                          │
│   └─────────┘     └─────────┘     └─────────┘                          │
│                                                                           │
│   ┌─────────┐                                                            │
│   │  Chat   │                                                            │
│   │   App   │                                                            │
│   └─────────┘                                                            │
└───────────────────────────────────────────────────────────────────────────┘
                              │
                              │
┌─────────────────────────────┼────────────────────────────────────────────┐
│                             │      DATA & STORAGE LAYER                   │
├─────────────────────────────┼────────────────────────────────────────────┤
│                             │                                            │
│         ┌───────────────────┼────────────────┐                           │
│         │                   │                │                           │
│         ▼                   ▼                ▼                           │
│   ┌──────────┐        ┌──────────┐    ┌──────────┐                     │
│   │PostgreSQL│        │ Supabase │    │ Firebase │                     │
│   │ Database │        │ Storage  │    │ Storage  │                     │
│   │          │        │ (Images) │    │ (Videos) │                     │
│   └──────────┘        └──────────┘    └──────────┘                     │
│                                                                           │
│   ┌──────────┐        ┌──────────┐                                      │
│   │  Redis   │        │ Dale AI  │                                      │
│   │(Channels)│        │   API    │                                      │
│   └──────────┘        └──────────┘                                      │
└───────────────────────────────────────────────────────────────────────────┘
```

## Detailed Component Flow

### 1. User Authentication Flow
```
┌─────────────┐
│   Mobile    │
│   Device    │
└──────┬──────┘
       │
       │ 1. Enter ID + DOB
       │    or Username + Password
       ▼
┌─────────────────────┐
│   Django Backend    │
│   /api/users/login/ │
└──────┬──────────────┘
       │
       │ 2. Validate credentials
       ▼
┌─────────────────────┐
│   PostgreSQL DB     │
│   User Table        │
└──────┬──────────────┘
       │
       │ 3. User found
       ▼
┌─────────────────────┐
│   Generate JWT      │
│   Access + Refresh  │
└──────┬──────────────┘
       │
       │ 4. Return tokens + user data
       ▼
┌─────────────┐
│   Mobile    │
│   Store     │
│   Tokens    │
└─────────────┘
```

### 2. QR Code Self-Service Flow
```
┌─────────────┐
│   Admin     │
│  Generates  │
│  QR Code    │
└──────┬──────┘
       │ Token embedded
       ▼
┌─────────────────────┐
│   User Scans QR     │
│   Opens Form        │
└──────┬──────────────┘
       │
       │ Fill details
       ▼
┌─────────────────────┐
│   POST /api/        │
│   submissions/      │
└──────┬──────────────┘
       │
       │ Verify token
       ▼
┌─────────────────────┐
│   Store in DB       │
│   Status: Pending   │
└──────┬──────────────┘
       │
       │ Admin reviews
       ▼
┌─────────────────────┐
│   Approve/Reject    │
└──────┬──────────────┘
       │
       │ If approved
       ▼
┌─────────────────────┐
│   Create User       │
│   Account           │
└─────────────────────┘
```

### 3. Social Feed Flow
```
┌─────────────┐
│   User      │
│   Creates   │
│   Post      │
└──────┬──────┘
       │
       │ POST with media
       ▼
┌─────────────────────┐
│   Django Backend    │
│   /api/posts/       │
└──────┬──────────────┘
       │
       ├──────────────┐
       │              │
       ▼              ▼
┌──────────┐    ┌──────────┐
│ Dale AI  │    │ Upload   │
│ Moderate │    │  Media   │
└────┬─────┘    └────┬─────┘
     │               │
     │ Safe          │ URL
     ▼               ▼
┌─────────────────────┐
│   Save to DB        │
│   PostgreSQL        │
└──────┬──────────────┘
       │
       │ Broadcast
       ▼
┌─────────────────────┐
│   Supabase          │
│   Real-time Update  │
└──────┬──────────────┘
       │
       │ Push to clients
       ▼
┌─────────────┐
│   All Users │
│   See Post  │
│   in Feed   │
└─────────────┘
```

### 4. Arcade Game Flow
```
┌─────────────┐
│   User      │
│   Selects   │
│   Game      │
└──────┬──────┘
       │
       │ Load game
       ▼
┌─────────────────────┐
│   Flutter Flame     │
│   Game Engine       │
└──────┬──────────────┘
       │
       │ Play game
       ▼
┌─────────────────────┐
│   Submit Score      │
│   POST /api/games/  │
│   {id}/score/       │
└──────┬──────────────┘
       │
       │ Validate
       ▼
┌─────────────────────┐
│   Save to DB        │
│   Update Leaderboard│
└──────┬──────────────┘
       │
       │ Check achievements
       ▼
┌─────────────────────┐
│   Dale AI           │
│   Generate Highlight│
└──────┬──────────────┘
       │
       │ Store highlight
       ▼
┌─────────────────────┐
│   Firebase Storage  │
│   Video Clip        │
└──────┬──────────────┘
       │
       │ Return results
       ▼
┌─────────────┐
│   Show      │
│   Results   │
│   + Share   │
└─────────────┘
```

### 5. Real-time Chat Flow
```
┌─────────────┐
│   User A    │
└──────┬──────┘
       │
       │ Connect WebSocket
       ▼
┌─────────────────────┐
│   Django Channels   │
│   ws://...chat/     │
└──────┬──────────────┘
       │
       │ Join room
       ▼
┌─────────────────────┐
│   Redis Channel     │
│   Layer             │
└──────┬──────────────┘
       │
       │ Broadcast ready
       ▼
┌─────────────┐
│   User A    │
│   Sends Msg │
└──────┬──────┘
       │
       │ Message data
       ▼
┌─────────────────────┐
│   Dale AI           │
│   Moderate Content  │
└──────┬──────────────┘
       │
       │ If safe
       ▼
┌─────────────────────┐
│   Save to DB        │
│   PostgreSQL        │
└──────┬──────────────┘
       │
       │ Broadcast
       ▼
┌─────────────────────┐
│   Redis → All       │
│   Room Members      │
└──────┬──────────────┘
       │
       ▼
┌─────────────┐
│   User B    │
│   Receives  │
│   Message   │
└─────────────┘
```

## Data Model Relationships

```
┌─────────────┐
│    User     │
│             │
│ - user_id   │
│ - role      │
│ - name      │
│ - dob       │
└──────┬──────┘
       │
       ├──────────────────┬──────────────────┬──────────────────┐
       │ creates          │ joins            │ plays            │
       ▼                  ▼                  ▼                  │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│    Post     │    │   Group     │    │    Game     │         │
│             │    │             │    │             │         │
│ - content   │    │ - name      │    │ - game_id   │         │
│ - media     │    │ - type      │    │ - name      │         │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
       │                  │                  │                 │
       │ has              │ has              │ has             │
       ▼                  ▼                  ▼                 │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│   Comment   │    │ Membership  │    │ GameScore   │◄────────┘
│             │    │             │    │             │
│ - content   │    │ - role      │    │ - score     │
└─────────────┘    └─────────────┘    │ - duration  │
                                      └─────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────┐
│           Security Layers               │
├─────────────────────────────────────────┤
│                                         │
│  1. HTTPS/WSS Encryption                │
│     └─ All communication encrypted      │
│                                         │
│  2. JWT Authentication                  │
│     ├─ Token in Authorization header    │
│     └─ Token refresh mechanism          │
│                                         │
│  3. Role-Based Permissions              │
│     ├─ Student access                   │
│     ├─ Staff access                     │
│     └─ Parent/Visitor access            │
│                                         │
│  4. Content Moderation                  │
│     └─ Dale AI automatic filtering      │
│                                         │
│  5. Rate Limiting                       │
│     └─ Prevent abuse                    │
│                                         │
│  6. CORS Protection                     │
│     └─ Allowed origins only             │
│                                         │
└─────────────────────────────────────────┘
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRODUCTION ENVIRONMENT                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │   Vercel     │         │  Render/     │                 │
│  │              │         │  Railway     │                 │
│  │  Flutter Web │◄───────►│  Django API  │                 │
│  └──────────────┘         └──────┬───────┘                 │
│                                  │                          │
│                    ┌─────────────┼─────────────┐            │
│                    │             │             │            │
│                    ▼             ▼             ▼            │
│            ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│            │ Supabase  │  │ Firebase  │  │ Dale AI   │    │
│            │ (DB+Store)│  │ (Videos)  │  │ (API)     │    │
│            └───────────┘  └───────────┘  └───────────┘    │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │  Play Store  │         │  App Store   │                 │
│  │              │         │              │                 │
│  │Android APK   │         │   iOS IPA    │                 │
│  └──────────────┘         └──────────────┘                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

**All systems designed for scalability and free-tier compatibility!**

# TCS Flutter Frontend Development Guide

## Overview
The TCS frontend is built with Flutter for cross-platform support (Android, iOS, Web), providing a seamless user experience across all devices.

## Project Structure

```
frontend/
├── lib/
│   ├── main.dart              # App entry point
│   ├── config/                # Configuration files
│   │   └── app_config.dart    # API endpoints, constants
│   ├── models/                # Data models
│   │   ├── user_model.dart
│   │   ├── post_model.dart
│   │   ├── group_model.dart
│   │   └── game_model.dart
│   ├── services/              # Business logic & API
│   │   ├── api_service.dart   # Base API client
│   │   ├── auth_service.dart  # Authentication
│   │   ├── post_service.dart  # Social features
│   │   ├── game_service.dart  # Arcade features
│   │   └── storage_service.dart  # Local storage
│   ├── screens/               # Full-page screens
│   │   ├── splash/
│   │   ├── onboarding/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── role_selection_screen.dart
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart
│   │   ├── feed/
│   │   │   ├── feed_screen.dart
│   │   │   └── post_detail_screen.dart
│   │   ├── groups/
│   │   │   ├── groups_screen.dart
│   │   │   └── group_detail_screen.dart
│   │   ├── arcade/
│   │   │   ├── arcade_screen.dart
│   │   │   ├── game_screen.dart
│   │   │   └── leaderboard_screen.dart
│   │   ├── chat/
│   │   │   ├── chat_list_screen.dart
│   │   │   └── chat_room_screen.dart
│   │   └── profile/
│   │       └── profile_screen.dart
│   ├── widgets/               # Reusable components
│   │   ├── common/
│   │   │   ├── custom_button.dart
│   │   │   ├── loading_indicator.dart
│   │   │   └── error_widget.dart
│   │   ├── post/
│   │   │   ├── post_card.dart
│   │   │   ├── post_input.dart
│   │   │   └── comment_item.dart
│   │   ├── game/
│   │   │   ├── game_card.dart
│   │   │   └── leaderboard_item.dart
│   │   └── chat/
│   │       └── message_bubble.dart
│   └── utils/                 # Helper functions
│       ├── validators.dart
│       ├── date_helper.dart
│       └── constants.dart
├── assets/
│   ├── images/
│   ├── icons/
│   ├── animations/
│   └── games/
└── pubspec.yaml
```

## Key Dependencies

### State Management
- **Provider**: For app-wide state
- **GetX**: For navigation and reactive state

### Networking
- **Dio**: HTTP client with interceptors
- **http**: Backup HTTP library

### Storage
- **SharedPreferences**: Simple key-value storage
- **FlutterSecureStorage**: Encrypted storage for tokens

### Firebase & Supabase
- **firebase_core**: Firebase initialization
- **firebase_storage**: Video/media storage
- **supabase_flutter**: Real-time updates

### UI Components
- **cached_network_image**: Efficient image loading
- **shimmer**: Loading placeholders
- **lottie**: Animations

### Games
- **flame**: 2D game engine
- **flame_audio**: Game audio

### QR Code
- **qr_flutter**: Generate QR codes
- **qr_code_scanner**: Scan QR codes

## Screen Flow

```
Splash Screen
    ↓
Language Selection
    ↓
Onboarding (first time)
    ↓
Role Selection
    ├── Student/Staff → ID + DOB Login
    └── Parent/Visitor → Email + Password Login
        ↓
    Dashboard
        ├── Feed Tab
        ├── Groups Tab
        ├── Events Tab
        ├── Arcade Tab
        └── Chat Tab
```

## Authentication Flow

### 1. ID + DOB Login (Students/Staff)
```dart
// In login_screen.dart
final authService = AuthService();

final result = await authService.loginWithId(
  userId: userIdController.text,
  dateOfBirth: selectedDate,
);

if (result['success']) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => DashboardScreen()),
  );
} else {
  // Show error
}
```

### 2. Username + Password Login (Parents/Visitors)
```dart
final result = await authService.loginWithPassword(
  identifier: usernameController.text,
  password: passwordController.text,
);
```

## State Management Pattern

### Provider Example
```dart
// Create provider
class UserProvider extends ChangeNotifier {
  User? _user;
  
  User? get user => _user;
  
  void setUser(User user) {
    _user = user;
    notifyListeners();
  }
  
  void logout() {
    _user = null;
    notifyListeners();
  }
}

// Use in main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => UserProvider()),
    ChangeNotifierProvider(create: (_) => PostProvider()),
  ],
  child: MyApp(),
)

// Access in widgets
final user = Provider.of<UserProvider>(context).user;
```

## API Integration

### Making API Calls
```dart
// Using ApiService
final apiService = ApiService();

// GET request
final response = await apiService.get('/posts/');
final posts = (response.data['results'] as List)
    .map((json) => Post.fromJson(json))
    .toList();

// POST request
await apiService.post('/posts/', data: {
  'content': 'Hello TCS!',
  'post_type': 'text',
});

// With file upload
final formData = FormData.fromMap({
  'content': 'Check this out!',
  'media': await MultipartFile.fromFile(imagePath),
});
await apiService.post('/posts/', data: formData);
```

## Real-time Features

### Supabase Real-time
```dart
// Listen to feed updates
final supabase = Supabase.instance.client;

supabase
  .from('posts')
  .stream(primaryKey: ['id'])
  .listen((List<Map<String, dynamic>> data) {
    // Update UI with new posts
  });
```

### WebSocket (Django Channels)
```dart
// Connect to chat
final channel = WebSocketChannel.connect(
  Uri.parse('ws://localhost:8000/ws/chat/$roomId/'),
);

// Listen for messages
channel.stream.listen((message) {
  final data = jsonDecode(message);
  // Update chat UI
});

// Send message
channel.sink.add(jsonEncode({
  'message': messageText,
  'user_id': currentUser.userId,
}));
```

## Navigation

### Using GetX
```dart
// Navigate to screen
Get.to(() => PostDetailScreen(postId: post.id));

// Replace current screen
Get.off(() => DashboardScreen());

// Clear stack and navigate
Get.offAll(() => LoginScreen());

// Navigate with arguments
Get.to(() => GameScreen(), arguments: {
  'game_id': 'campus_craft',
  'mode': 'solo',
});

// Access arguments
final args = Get.arguments;
final gameId = args['game_id'];
```

## UI Components

### Custom Button
```dart
// widgets/common/custom_button.dart
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  
  // Implementation...
}

// Usage
CustomButton(
  text: 'Login',
  onPressed: () => handleLogin(),
  isLoading: isLoading,
)
```

### Post Card
```dart
// widgets/post/post_card.dart
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  
  // Implementation...
}
```

## Arcade Integration

### Game Screen Structure
```dart
// screens/arcade/game_screen.dart
class GameScreen extends StatefulWidget {
  final String gameId;
  
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameEngine gameEngine;
  
  @override
  void initState() {
    super.initState();
    gameEngine = GameEngine(gameId: widget.gameId);
  }
  
  void submitScore(int score) async {
    await gameService.submitScore(
      gameId: widget.gameId,
      score: score,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: gameEngine),
    );
  }
}
```

## Theme & Styling

### Define Theme
```dart
// main.dart
MaterialApp(
  theme: ThemeData(
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    // ... more theme properties
  ),
)
```

## Error Handling

### Global Error Handler
```dart
// utils/error_handler.dart
class ErrorHandler {
  static void handle(BuildContext context, dynamic error) {
    String message = 'An error occurred';
    
    if (error is DioException) {
      message = error.response?.data['error'] ?? error.message;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
```

## Local Storage

### Saving User Preferences
```dart
// services/storage_service.dart
class StorageService {
  static final _prefs = SharedPreferences.getInstance();
  
  static Future<void> saveLanguage(String lang) async {
    final prefs = await _prefs;
    await prefs.setString('language', lang);
  }
  
  static Future<String?> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString('language');
  }
}
```

## Testing

### Widget Tests
```dart
// test/widget_test.dart
void main() {
  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
```

## Build & Release

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Next Steps

### Immediate Implementation Tasks
1. Create login screens (ID + DOB, Username + Password)
2. Build dashboard with bottom navigation
3. Implement feed screen with posts
4. Create group listing and detail screens
5. Integrate first arcade game (Campus Craft)
6. Implement chat interface
7. Add profile screen

### Testing Checklist
- [ ] Authentication flow
- [ ] API integration
- [ ] Real-time updates
- [ ] Game functionality
- [ ] Cross-platform compatibility
- [ ] Offline handling
- [ ] Performance optimization

---

**Ready to build the TCS experience!** 🚀

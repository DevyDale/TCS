class AppConfig {
  // API Configuration — iOS Simulator / Mac browser
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String wsUrl   = 'ws://127.0.0.1:8000';

  // Android Emulator → uncomment when running on Android
  // static const String baseUrl = 'http://10.0.2.2:8000';
  // static const String wsUrl   = 'ws://10.0.2.2:8000';

  // Physical device on same WiFi → run `ipconfig getifaddr en0`
  // static const String baseUrl = 'http://192.168.x.x:8000';
  // static const String wsUrl   = 'ws://192.168.x.x:8000';

  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseKey = 'YOUR_SUPABASE_KEY';

  // Firebase Configuration
  // Add your Firebase configuration in firebase_options.dart

  // App Configuration
  static const String appName    = 'TCS';
  static const String appVersion = '1.0.0';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout    = Duration(seconds: 30);
}
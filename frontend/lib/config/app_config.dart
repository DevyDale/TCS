class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://192.168.68.107:8000';
  static const String wsUrl = 'ws://192.168.68.107:8000';
  
  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseKey = 'YOUR_SUPABASE_KEY';
  
  // Firebase Configuration
  // Add your Firebase configuration in firebase_options.dart
  
  // App Configuration
  static const String appName = 'TCS';
  static const String appVersion = '1.0.0';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

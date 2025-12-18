import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  
  // Login with ID and Date of Birth (for students/staff)
  Future<Map<String, dynamic>> loginWithId({
    required String userId,
    required DateTime dateOfBirth,
  }) async {
    try {
      final response = await _apiService.post('/users/login/', data: {
        'user_id': userId,
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
      });
      
      // Store tokens
      await _apiService.setTokens(
        response.data['access'],
        response.data['refresh'],
      );
      
      return {
        'success': true,
        'user': User.fromJson(response.data['user']),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Login with username/email and password (for parents/visitors)
  Future<Map<String, dynamic>> loginWithPassword({
    required String identifier, // username or email
    required String password,
  }) async {
    try {
      final response = await _apiService.post('/users/login-password/', data: {
        'identifier': identifier,
        'password': password,
      });
      
      // Store tokens
      await _apiService.setTokens(
        response.data['access'],
        response.data['refresh'],
      );
      
      return {
        'success': true,
        'user': User.fromJson(response.data['user']),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Logout
  Future<void> logout() async {
    await _apiService.clearTokens();
  }
  
  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      final response = await _apiService.get('/users/me/');
      return User.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }
}

import 'dart:convert';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  static Future<User> signup({
    required String name,
    required String nyuEmail,
    required String nyuId,
    required String password,
    required String major,
    String? minor,
    required int academicStanding,
    required int workWillingness,
    String? preferredLocation,
    String? timePreference,
    double? gpa,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'nyu_email': nyuEmail,
      'nyu_id': nyuId,
      'password': password,
      'major': major,
      'academic_standing': academicStanding,
      'work_willingness': workWillingness,
    };
    if (minor != null) body['minor'] = minor;
    if (preferredLocation != null) body['preferred_location'] = preferredLocation;
    if (timePreference != null) body['time_preference'] = timePreference;
    if (gpa != null) body['gpa'] = gpa;

    final response = await ApiClient.post('/auth/signup', body: body, withAuth: false);
    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Signup failed');
  }

  static Future<Map<String, dynamic>> login({
    required String nyuEmail,
    required String password,
  }) async {
    final response = await ApiClient.post('/auth/login', body: {
      'nyu_email': nyuEmail,
      'password': password,
    }, withAuth: false);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Login failed');
  }

  static Future<void> logout() async {
    await ApiClient.post('/auth/logout');
  }

  static Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await ApiClient.post('/auth/refresh', body: {
      'refresh_token': refreshToken,
    }, withAuth: false);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Token refresh failed');
  }

  static Future<void> requestPasswordReset(String email) async {
    await ApiClient.post('/auth/password-reset/request', body: {
      'email': email,
    }, withAuth: false);
  }

  static Future<void> confirmPasswordReset(String newPassword) async {
    await ApiClient.post('/auth/password-reset/confirm', body: {
      'new_password': newPassword,
    }, withAuth: false);
  }
}

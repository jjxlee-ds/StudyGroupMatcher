import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<void> login(String nyuEmail, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await AuthService.login(nyuEmail: nyuEmail, password: password);
      final token = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      if (refreshToken != null) {
        await prefs.setString('refresh_token', refreshToken);
      }
      _user = User.fromJson(data['user']);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signup({
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
    _isLoading = true;
    notifyListeners();
    try {
      await AuthService.signup(
        name: name,
        nyuEmail: nyuEmail,
        nyuId: nyuId,
        password: password,
        major: major,
        minor: minor,
        academicStanding: academicStanding,
        workWillingness: workWillingness,
        preferredLocation: preferredLocation,
        timePreference: timePreference,
        gpa: gpa,
      );
      // Signup doesn't return a token, so auto-login
      await login(nyuEmail, password);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await AuthService.logout();
    } catch (_) {
      // Ignore logout errors
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    _user = null;
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      _user = await UserService.getMe();
    } catch (_) {
      await prefs.remove('access_token');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }
}

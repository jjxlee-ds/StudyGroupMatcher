import 'dart:convert';
import '../models/user.dart';
import 'api_client.dart';

class UserService {
  static Future<User> getMe() async {
    final response = await ApiClient.get('/users/me');
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch current user');
  }

  static Future<User> getUser(String userId) async {
    final response = await ApiClient.get('/users/$userId');
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch user');
  }

  static Future<User> updateMe(UserUpdate update) async {
    final response = await ApiClient.put('/users/me', body: update.toJson());
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update user');
  }

  static Future<void> deleteMe() async {
    final response = await ApiClient.delete('/users/me');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete user');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiClient {
  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns true if refresh succeeded and new tokens are saved.
  static Future<bool> _tryRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) return false;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/refresh');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await prefs.setString('access_token', data['access_token'] as String);
        final newRefresh = data['refresh_token'] as String?;
        if (newRefresh != null) {
          await prefs.setString('refresh_token', newRefresh);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<http.Response> get(String path, {bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    var headers = await _headers(withAuth: withAuth);
    var response = await http.get(url, headers: headers);
    if (response.statusCode == 401 && withAuth) {
      if (await _tryRefreshToken()) {
        headers = await _headers(withAuth: true);
        response = await http.get(url, headers: headers);
      }
    }
    return response;
  }

  static Future<http.Response> post(String path,
      {Map<String, dynamic>? body, bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    var headers = await _headers(withAuth: withAuth);
    var response =
        await http.post(url, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 401 && withAuth) {
      if (await _tryRefreshToken()) {
        headers = await _headers(withAuth: true);
        response =
            await http.post(url, headers: headers, body: jsonEncode(body));
      }
    }
    return response;
  }

  static Future<http.Response> put(String path,
      {Map<String, dynamic>? body, bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    var headers = await _headers(withAuth: withAuth);
    var response =
        await http.put(url, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 401 && withAuth) {
      if (await _tryRefreshToken()) {
        headers = await _headers(withAuth: true);
        response =
            await http.put(url, headers: headers, body: jsonEncode(body));
      }
    }
    return response;
  }

  static Future<http.Response> delete(String path,
      {bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    var headers = await _headers(withAuth: withAuth);
    var response = await http.delete(url, headers: headers);
    if (response.statusCode == 401 && withAuth) {
      if (await _tryRefreshToken()) {
        headers = await _headers(withAuth: true);
        response = await http.delete(url, headers: headers);
      }
    }
    return response;
  }
}

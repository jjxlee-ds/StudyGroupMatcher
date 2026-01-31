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

  static Future<http.Response> get(String path, {bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers(withAuth: withAuth);
    return http.get(url, headers: headers);
  }

  static Future<http.Response> post(String path,
      {Map<String, dynamic>? body, bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers(withAuth: withAuth);
    return http.post(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> put(String path,
      {Map<String, dynamic>? body, bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers(withAuth: withAuth);
    return http.put(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> delete(String path,
      {bool withAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers(withAuth: withAuth);
    return http.delete(url, headers: headers);
  }
}

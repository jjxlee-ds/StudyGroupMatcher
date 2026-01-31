import 'dart:convert';
import '../models/course.dart';
import 'api_client.dart';

class CourseService {
  static Future<List<Course>> getAll() async {
    final response = await ApiClient.get('/courses/', withAuth: false);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Course.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch courses');
  }

  static Future<List<Course>> search(String courseCode) async {
    final response = await ApiClient.get(
      '/courses/search?course_code=${Uri.encodeComponent(courseCode)}',
      withAuth: false,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Course.fromJson(json)).toList();
    }
    throw Exception('Failed to search courses');
  }

  static Future<Course> getById(int courseId) async {
    final response = await ApiClient.get('/courses/$courseId', withAuth: false);
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch course');
  }

  static Future<Course> create({
    required String courseCode,
    required String courseName,
    required int courseSection,
  }) async {
    final response = await ApiClient.post('/courses/', body: {
      'course_code': courseCode,
      'course_name': courseName,
      'course_section': courseSection,
    }, withAuth: false);
    if (response.statusCode == 201) {
      return Course.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create course');
  }
}

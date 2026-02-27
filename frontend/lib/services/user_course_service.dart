import 'dart:convert';
import '../models/user_course.dart';
import 'api_client.dart';

class UserCourseService {
  static Future<List<UserCourse>> getMyCourses() async {
    final response = await ApiClient.get('/user-courses/');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => UserCourse.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch enrolled courses');
  }

  static Future<UserCourse> enroll({
    required String nyuId,
    required int courseId,
    required String semester,
    required String currentCourseTimeStart,
    required String currentCourseTimeEnd,
  }) async {
    final response = await ApiClient.post('/user-courses/', body: {
      'nyu_id': nyuId,
      'course_id': courseId,
      'semester': semester,
      'current_course_time_start': currentCourseTimeStart,
      'current_course_time_end': currentCourseTimeEnd,
    });
    if (response.statusCode == 201) {
      return UserCourse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to enroll in course');
  }

  static Future<void> unenroll(int enrollmentId) async {
    final response = await ApiClient.delete('/user-courses/$enrollmentId');
    if (response.statusCode != 204) {
      throw Exception('Failed to unenroll from course');
    }
  }
}

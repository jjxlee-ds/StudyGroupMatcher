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
    required int courseId,
    required String term,
    required int year,
    String? startTime,
    String? endTime,
  }) async {
    final body = <String, dynamic>{
      'course_id': courseId,
      'term': term,
      'year': year,
    };
    if (startTime != null) body['start_time'] = startTime;
    if (endTime != null) body['end_time'] = endTime;
    final response = await ApiClient.post('/user-courses/', body: body);
    if (response.statusCode == 201) {
      return UserCourse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to enroll in course');
  }

  static Future<void> unenroll(int courseId) async {
    final response = await ApiClient.delete('/user-courses/?course_id=$courseId');
    if (response.statusCode != 204) {
      throw Exception('Failed to unenroll from course');
    }
  }
}

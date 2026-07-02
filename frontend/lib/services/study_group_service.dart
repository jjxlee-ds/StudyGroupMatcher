import 'dart:convert';
import '../models/study_group.dart';
import 'api_client.dart';

class StudyGroupService {
  static Future<List<StudyGroupRecommendation>> getRecommendations({int limit = 10}) async {
    final response = await ApiClient.get('/study-groups/recommend?limit=$limit');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StudyGroupRecommendation.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch recommendations');
  }

  static Future<List<StudyGroup>> getMyStudyGroups() async {
    final response = await ApiClient.get('/study-groups/me');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StudyGroup.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch study groups');
  }

  static Future<List<StudyGroup>> getByCourse(String courseId) async {
    final response = await ApiClient.get('/study-groups/course/$courseId');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StudyGroup.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch study groups for course');
  }

  static Future<StudyGroup> create({
    required int courseId,
    required String name,
    required int maxMembers,
    String? location,
  }) async {
    final response = await ApiClient.post('/study-groups/', body: {
      'course_id': courseId,
      'name': name,
      'max_members': maxMembers,
      'location': location,
    });
    if (response.statusCode == 201) {
      return StudyGroup.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create study group');
  }

  static Future<void> join(String groupId) async {
    final response = await ApiClient.post('/study-groups/$groupId/join', body: {});
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      final detail = body['detail'] as String? ?? 'Failed to join study group';
      throw Exception(detail);
    }
  }

  static Future<void> leave(String groupId) async {
    final response = await ApiClient.delete('/study-groups/$groupId/leave');
    if (response.statusCode != 204) {
      throw Exception('Failed to leave study group');
    }
  }

  /// Returns a map of user_id → name for all members of a group.
  static Future<Map<String, String>> getMemberNames(String groupId) async {
    try {
      final response = await ApiClient.get('/study-groups/$groupId/members');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final map = <String, String>{};
        for (final m in data) {
          final userId = m['user_id'];
          final name = m['name'];
          if (userId is String && userId.isNotEmpty) {
            map[userId] = (name is String && name.isNotEmpty) ? name : 'Member';
          }
        }
        return map;
      }
    } catch (e) {
      throw Exception('Failed to load group members: $e');
    }
    return {};
  }
}

import 'dart:convert';
import 'api_client.dart';

class JoinRequest {
  final String id;
  final String studyGroupId;
  final String userId;
  final String status;
  final DateTime createdAt;
  final JoinRequestUser? user;

  JoinRequest({
    required this.id,
    required this.studyGroupId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.user,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] as String,
      studyGroupId: json['study_group_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      user: json['user'] != null
          ? JoinRequestUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class JoinRequestUser {
  final String id;
  final String name;
  final String major;
  final String? minor;
  final int academicStanding;
  final int workWillingness;
  final double? avgGpa;
  final String preferredLocation;
  final String timePreference;

  JoinRequestUser({
    required this.id,
    required this.name,
    required this.major,
    this.minor,
    required this.academicStanding,
    required this.workWillingness,
    this.avgGpa,
    required this.preferredLocation,
    required this.timePreference,
  });

  factory JoinRequestUser.fromJson(Map<String, dynamic> json) {
    return JoinRequestUser(
      id: json['id'] as String,
      name: json['name'] as String,
      major: json['major'] as String,
      minor: json['minor'] as String?,
      academicStanding: json['academic_standing'] as int,
      workWillingness: json['work_willingness'] as int,
      avgGpa: (json['avg_gpa'] as num?)?.toDouble(),
      preferredLocation: json['preferred_location'] as String? ?? '',
      timePreference: json['time_preference'] as String? ?? '',
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

class JoinRequestService {
  static Future<List<JoinRequest>> getRequests(String groupId) async {
    final res = await ApiClient.get('/study-groups/$groupId/requests');
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load join requests (${res.statusCode})');
  }

  static Future<void> accept(String groupId, String requestId) async {
    final res = await ApiClient.post(
      '/study-groups/$groupId/requests/$requestId/accept',
      body: {},
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Failed to accept');
    }
  }

  static Future<void> decline(String groupId, String requestId) async {
    final res = await ApiClient.post(
      '/study-groups/$groupId/requests/$requestId/decline',
      body: {},
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Failed to decline');
    }
  }
}

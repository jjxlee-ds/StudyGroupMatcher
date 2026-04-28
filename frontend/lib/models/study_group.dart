class StudyGroup {
  final String id;
  final int courseId;
  final String name;
  final int maxMembers;
  final String? location;
  final String? createdAt;
  final int? currentMembers;
  final String? adminId;

  StudyGroup({
    required this.id,
    required this.courseId,
    required this.name,
    required this.maxMembers,
    this.location,
    this.createdAt,
    this.currentMembers,
    this.adminId,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    return StudyGroup(
      id: json['id'] as String,
      courseId: json['course_id'] as int,
      name: json['name'] as String,
      maxMembers: json['max_members'] as int,
      location: json['location'] as String?,
      createdAt: json['created_at'] as String?,
      currentMembers: json['current_members'] as int?,
      adminId: json['admin_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,  // int
      'name': name,
      'max_members': maxMembers,
      'location': location,
      'created_at': createdAt,
      'current_members': currentMembers,
      'admin_id': adminId,
    };
  }
}

class ScoreBreakdown {
  final double workWillingness;
  final double gpa;
  final double location;
  final double timePreference;

  ScoreBreakdown({
    required this.workWillingness,
    required this.gpa,
    required this.location,
    required this.timePreference,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      workWillingness: (json['work_willingness'] as num).toDouble(),
      gpa: (json['gpa'] as num).toDouble(),
      location: (json['location'] as num).toDouble(),
      timePreference: (json['time_preference'] as num).toDouble(),
    );
  }
}

class StudyGroupRecommendation {
  final String id;
  final int courseId;
  final String name;
  final int maxMembers;
  final String? location;
  final String? createdAt;
  final int currentMembers;
  final double matchScore;
  final ScoreBreakdown scoreBreakdown;

  StudyGroupRecommendation({
    required this.id,
    required this.courseId,
    required this.name,
    required this.maxMembers,
    this.location,
    this.createdAt,
    required this.currentMembers,
    required this.matchScore,
    required this.scoreBreakdown,
  });

  factory StudyGroupRecommendation.fromJson(Map<String, dynamic> json) {
    return StudyGroupRecommendation(
      id: json['id'] as String,
      courseId: json['course_id'] as int,
      name: json['name'] as String,
      maxMembers: json['max_members'] as int,
      location: json['location'] as String?,
      createdAt: json['created_at'] as String?,
      currentMembers: json['current_members'] as int,
      matchScore: (json['match_score'] as num).toDouble(),
      scoreBreakdown: ScoreBreakdown.fromJson(json['score_breakdown']),
    );
  }
}

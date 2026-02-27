class StudyGroup {
  final String id;
  final String courseId;
  final String name;
  final int maxMembers;
  final String? location;
  final String? createdAt;
  final int? currentMembers;

  StudyGroup({
    required this.id,
    required this.courseId,
    required this.name,
    required this.maxMembers,
    this.location,
    this.createdAt,
    this.currentMembers,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    return StudyGroup(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      name: json['name'] as String,
      maxMembers: json['max_members'] as int,
      location: json['location'] as String?,
      createdAt: json['created_at'] as String?,
      currentMembers: json['current_members'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'name': name,
      'max_members': maxMembers,
      'location': location,
      'created_at': createdAt,
      'current_members': currentMembers,
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
  final String courseId;
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
      courseId: json['course_id'] as String,
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

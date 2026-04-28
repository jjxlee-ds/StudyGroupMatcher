class UserCourse {
  final String userId;
  final int courseId;
  final String term;
  final int year;
  final String? startTime;
  final String? endTime;
  final String? createdAt;

  UserCourse({
    required this.userId,
    required this.courseId,
    required this.term,
    required this.year,
    this.startTime,
    this.endTime,
    this.createdAt,
  });

  factory UserCourse.fromJson(Map<String, dynamic> json) {
    return UserCourse(
      userId: json['user_id'] as String,
      courseId: json['course_id'] as int,
      term: json['term'] as String,
      year: json['year'] as int,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

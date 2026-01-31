class UserCourse {
  final int? id;
  final String nyuId;
  final int courseId;
  final int courseSection;
  final String semester;
  final String currentCourseTimeStart;
  final String currentCourseTimeEnd;
  final String? createdAt;

  UserCourse({
    this.id,
    required this.nyuId,
    required this.courseId,
    required this.courseSection,
    required this.semester,
    required this.currentCourseTimeStart,
    required this.currentCourseTimeEnd,
    this.createdAt,
  });

  factory UserCourse.fromJson(Map<String, dynamic> json) {
    return UserCourse(
      id: json['id'] as int?,
      nyuId: json['nyu_id'] as String,
      courseId: json['course_id'] as int,
      courseSection: json['course_section'] as int,
      semester: json['semester'] as String,
      currentCourseTimeStart: json['current_course_time_start'] as String,
      currentCourseTimeEnd: json['current_course_time_end'] as String,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nyu_id': nyuId,
      'course_id': courseId,
      'course_section': courseSection,
      'semester': semester,
      'current_course_time_start': currentCourseTimeStart,
      'current_course_time_end': currentCourseTimeEnd,
    };
  }
}

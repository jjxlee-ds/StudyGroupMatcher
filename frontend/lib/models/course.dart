class Course {
  final int id;
  final String courseCode;
  final String courseName;

  Course({
    required this.id,
    required this.courseCode,
    required this.courseName,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as int,
      courseCode: json['course_code'] as String,
      courseName: json['course_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_code': courseCode,
      'course_name': courseName,
    };
  }
}

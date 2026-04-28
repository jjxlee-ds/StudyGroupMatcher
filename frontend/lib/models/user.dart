class User {
  final String id;
  final String name;
  final String nyuEmail;
  final String nyuId;
  final String major;
  final String? minor;
  final int academicStanding;
  final int workWillingness;
  final String preferredLocation;
  final String timePreference;
  final double? gpa;

  User({
    required this.id,
    required this.name,
    required this.nyuEmail,
    required this.nyuId,
    required this.major,
    this.minor,
    required this.academicStanding,
    required this.workWillingness,
    required this.preferredLocation,
    required this.timePreference,
    this.gpa,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      nyuEmail: json['nyu_email'] as String,
      nyuId: json['nyu_id'] as String,
      major: json['major'] as String,
      minor: json['minor'] as String?,
      academicStanding: json['academic_standing'] as int,
      workWillingness: json['work_willingness'] as int,
      preferredLocation: json['preferred_location'] as String? ?? '',
      timePreference: json['time_preference'] as String? ?? '',
      gpa: (json['avg_gpa'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nyu_email': nyuEmail,
      'nyu_id': nyuId,
      'major': major,
      'minor': minor,
      'academic_standing': academicStanding,
      'work_willingness': workWillingness,
      'preferred_location': preferredLocation,
      'time_preference': timePreference,
      'avg_gpa': gpa,
    };
  }
}

class UserUpdate {
  final String? name;
  final String? major;
  final String? minor;
  final int? academicStanding;
  final int? workWillingness;
  final String? password;
  final String? preferredLocation;
  final String? timePreference;
  final double? gpa;

  UserUpdate({
    this.name,
    this.major,
    this.minor,
    this.academicStanding,
    this.workWillingness,
    this.password,
    this.preferredLocation,
    this.timePreference,
    this.gpa,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (major != null) map['major'] = major;
    if (minor != null) map['minor'] = minor;
    if (academicStanding != null) map['academic_standing'] = academicStanding;
    if (workWillingness != null) map['work_willingness'] = workWillingness;
    if (password != null) map['password'] = password;
    if (preferredLocation != null) map['preferred_location'] = preferredLocation;
    if (timePreference != null) map['time_preference'] = timePreference;
    if (gpa != null) map['avg_gpa'] = gpa;
    return map;
  }
}

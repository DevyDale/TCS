class User {
  final String userId;
  final String role;
  final String name;
  final String? preferredName;
  final DateTime dateOfBirth;
  final String? gender;
  final String? email;
  final String? username;
  final String? program;
  final String? electives;
  final String? subjectsTaught;
  final String? avatar;
  final String? bio;
  final bool isActive;
  final bool isVerified;
  final DateTime dateJoined;
  
  User({
    required this.userId,
    required this.role,
    required this.name,
    this.preferredName,
    required this.dateOfBirth,
    this.gender,
    this.email,
    this.username,
    this.program,
    this.electives,
    this.subjectsTaught,
    this.avatar,
    this.bio,
    required this.isActive,
    required this.isVerified,
    required this.dateJoined,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      role: json['role'],
      name: json['name'],
      preferredName: json['preferred_name'],
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      gender: json['gender'],
      email: json['email'],
      username: json['username'],
      program: json['program'],
      electives: json['electives'],
      subjectsTaught: json['subjects_taught'],
      avatar: json['avatar'],
      bio: json['bio'],
      isActive: json['is_active'],
      isVerified: json['is_verified'],
      dateJoined: DateTime.parse(json['date_joined']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role,
      'name': name,
      'preferred_name': preferredName,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'email': email,
      'username': username,
      'program': program,
      'electives': electives,
      'subjects_taught': subjectsTaught,
      'avatar': avatar,
      'bio': bio,
      'is_active': isActive,
      'is_verified': isVerified,
      'date_joined': dateJoined.toIso8601String(),
    };
  }
  
  String get displayName => preferredName ?? name;
}

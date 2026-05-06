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
  final int xp;
  final int level;
  final String? accessToken;

  const User({
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
    this.xp = 0,
    this.level = 1,
    this.accessToken,
  });

  // ── Derived helpers ─────────────────────────────────────────

  /// Preferred name falling back to first name
  String get displayName => preferredName ?? name.split(' ').first;

  /// Full display name
  String get fullDisplayName => name;

  /// Role formatted for display
  String get roleLabel {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'teaching_staff':
      case 'staff':
        return 'Staff';
      case 'non_teaching_staff':
        return 'Non-Teaching Staff';
      case 'parent':
        return 'Parent';
      case 'visitor':
        return 'Visitor';
      default:
        return role;
    }
  }

  bool get isStudent => role.toLowerCase() == 'student';
  bool get isStaff =>
      role.toLowerCase() == 'teaching_staff' ||
      role.toLowerCase() == 'staff' ||
      role.toLowerCase() == 'non_teaching_staff';
  bool get isParentOrVisitor =>
      role.toLowerCase() == 'parent' || role.toLowerCase() == 'visitor';

  // ── Serialisation ────────────────────────────────────────────

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      name: json['name'] as String? ?? '',
      preferredName: json['preferred_name'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : DateTime(2000),
      gender: json['gender'] as String?,
      email: json['email'] as String?,
      username: json['username'] as String?,
      program: json['program'] as String?,
      electives: json['electives'] as String?,
      subjectsTaught: json['subjects_taught'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      dateJoined: json['date_joined'] != null
          ? DateTime.parse(json['date_joined'] as String)
          : DateTime.now(),
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      accessToken: json['access_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'role': role,
        'name': name,
        'preferred_name': preferredName,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
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
        'xp': xp,
        'level': level,
      };

  User copyWith({
    String? userId,
    String? role,
    String? name,
    String? preferredName,
    DateTime? dateOfBirth,
    String? gender,
    String? email,
    String? username,
    String? program,
    String? electives,
    String? subjectsTaught,
    String? avatar,
    String? bio,
    bool? isActive,
    bool? isVerified,
    DateTime? dateJoined,
    int? xp,
    int? level,
    String? accessToken,
  }) {
    return User(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      name: name ?? this.name,
      preferredName: preferredName ?? this.preferredName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      username: username ?? this.username,
      program: program ?? this.program,
      electives: electives ?? this.electives,
      subjectsTaught: subjectsTaught ?? this.subjectsTaught,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      dateJoined: dateJoined ?? this.dateJoined,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      accessToken: accessToken ?? this.accessToken,
    );
  }

  @override
  String toString() => 'User(id: $userId, name: $name, role: $role)';
}
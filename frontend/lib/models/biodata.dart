// lib/models/bio_data.dart
// Shared data model between BioPage and ProfileScreen

class BioData {
  final String? dob;
  final int?    age;
  final String? country;
  final String? year;
  final String? major;
  final String? school;
  final String? bio;
  final String? achievements;
  final String? pronouns;
  final String? quote;
  final String? studyStyle;
  final String? studyTime;
  final String? studyMode;
  final List<String> subjects;
  final List<String> availableDays;
  final bool availableForStudy;
  // Privacy
  final bool showPersonal;
  final bool showAcademic;
  final bool showAvailability;
  final bool allowRequests;
  final bool schoolOnly;

  const BioData({
    this.dob,
    this.age,
    this.country,
    this.year,
    this.major,
    this.school,
    this.bio,
    this.achievements,
    this.pronouns,
    this.quote,
    this.studyStyle,
    this.studyTime,
    this.studyMode,
    this.subjects          = const [],
    this.availableDays     = const [],
    this.availableForStudy = false,
    this.showPersonal      = true,
    this.showAcademic      = true,
    this.showAvailability  = true,
    this.allowRequests     = true,
    this.schoolOnly        = false,
  });

  bool get isEmpty =>
      dob == null && country == null && year == null &&
      school == null && bio == null;
}
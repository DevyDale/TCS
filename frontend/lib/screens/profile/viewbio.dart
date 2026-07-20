import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:intl/intl.dart';

class BioPage extends StatefulWidget {
  const BioPage({super.key});

  @override
  State<BioPage> createState() => _BioPageState();
}

class _BioPageState extends State<BioPage> {
  // Controllers
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _achievementsController = TextEditingController();
  final TextEditingController _pronounsController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();

  DateTime? _dob;
  int? _age;
  String? _country;
  String? _year;
  final List<String> _selectedSubjects = [];
  String? _major;
  String? _studyStyle;
  String? _studyTime;
  String? _studyMode;
  bool _availableForStudy = false;
  final List<String> _availableDays = [];
  String? _profileColor;
  bool _showPersonal = true;
  bool _showAcademic = true;
  bool _showAvailability = true;
  bool _allowRequests = true;
  bool _schoolOnly = true;

  // Sample data
  final List<String> _countries = [
    'United States', 'United Kingdom', 'Canada', 'Australia', 'India', 'Nigeria', 'South Africa', 'Singapore', 'Other...'
  ];
  final List<String> _years = [
    'Year 7', 'Year 8', 'Year 9', 'Year 10', 'Year 11', 'Year 12', 'Year 13', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12', 'Freshman', 'Sophomore', 'Junior', 'Senior'
  ];
  final List<String> _subjects = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'History', 'Geography', 'Computer Science', 'Economics', 'Business', 'Art', 'Music', 'Physical Education', 'Other'
  ];
  final List<String> _majors = ['STEM', 'Arts', 'Commerce', 'Humanities', 'Other'];
  final List<String> _studyStyles = ['Quiet / Independent', 'Discussion / Group', 'Problem-solving / Practice'];
  final List<String> _studyTimes = ['Morning', 'Afternoon', 'Evening'];
  final List<String> _studyModes = ['Online', 'In-person', 'Both'];
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _profileColors = ['Blue', 'Purple', 'Pink', 'Orange', 'Green', 'Teal'];

  double get _completion {
    int total = 0, filled = 0;
    // Required: DOB, Country, Year, Subjects, School
    total += 5;
    if (_dob != null) filled++;
    if (_country != null && _country!.isNotEmpty) filled++;
    if (_year != null && _year!.isNotEmpty) filled++;
    if (_selectedSubjects.isNotEmpty) filled++;
    if (_schoolController.text.trim().isNotEmpty) filled++;
    return filled / total;
  }

  @override
  void dispose() {
    _dobController.dispose();
    _bioController.dispose();
    _schoolController.dispose();
    _achievementsController.dispose();
    _pronounsController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  void _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 16),
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year - 10),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
        _age = now.year - picked.year - ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: T(
          'Student Bio',
          style: TextStyle(
            color: AppC.text,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple, Colors.pink, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppC.isDark
                ? [AppC.bg, AppC.bg]
                : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 32),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 500,
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: AppC.card,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile completion
                      LinearProgressIndicator(
                        value: _completion,
                        minHeight: 7,
                        backgroundColor: Colors.blue.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 18),
                      T('Profile completion: {(_completion * 100).toStringAsFixed(0)}%', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      _sectionHeader('Personal Info'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dobController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Date of Birth (required)'),
                          suffixIcon: const Icon(Icons.calendar_today_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onTap: _pickDOB,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const T('Age:', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(_age != null ? '$_age' : '--', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _country,
                        items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _country = v),
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Country (required)'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _sectionHeader('Academic Info'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _year,
                        items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                        onChanged: (v) => setState(() => _year = v),
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Year / Grade (required)'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Course / Subjects (required)'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          children: _subjects.map((subject) {
                            final selected = _selectedSubjects.contains(subject);
                            return FilterChip(
                              label: Text(subject),
                              selected: selected,
                              backgroundColor: selected ? Colors.blue.shade100 : AppC.card2,
                              selectedColor: Colors.blue.shade300,
                              labelStyle: TextStyle(color: selected ? Colors.blue.shade900 : AppC.text),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedSubjects.add(subject);
                                  } else {
                                    _selectedSubjects.remove(subject);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _major,
                        items: [null, ..._majors].map((m) => DropdownMenuItem(value: m, child: Text(m ?? 'None'))).toList(),
                        onChanged: (v) => setState(() => _major = v),
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Major / Stream / Focus (optional)'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _schoolController,
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('School / Campus (required)'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _sectionHeader('Study Preferences'),
                      const SizedBox(height: 12),
                      _buildRadioGroup('Study Style', _studyStyles, _studyStyle, (v) => setState(() => _studyStyle = v)),
                      const SizedBox(height: 12),
                      _buildRadioGroup('Preferred Study Time', _studyTimes, _studyTime, (v) => setState(() => _studyTime = v)),
                      const SizedBox(height: 12),
                      _buildRadioGroup('Study Mode', _studyModes, _studyMode, (v) => setState(() => _studyMode = v)),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _availableForStudy,
                        onChanged: (v) => setState(() => _availableForStudy = v),
                        title: const T('Available for study'),
                        activeThumbColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      if (_availableForStudy)
                        Wrap(
                          spacing: 8,
                          children: _days.map((d) {
                            final selected = _availableDays.contains(d);
                            return FilterChip(
                              label: Text(d),
                              selected: selected,
                              backgroundColor: selected ? Colors.orange.shade100 : AppC.card2,
                              selectedColor: Colors.orange.shade300,
                              labelStyle: TextStyle(color: selected ? Colors.orange.shade900 : AppC.text),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _availableDays.add(d);
                                  } else {
                                    _availableDays.remove(d);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 28),
                      _sectionHeader('Short Bio / About Me'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bioController,
                        maxLength: 150,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: TranslationService.I.tr('One sentence about yourself or your study goals'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 28),
                      _sectionHeader('Achievements / Badges'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _achievementsController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: TranslationService.I.tr('E.g. Top Math Student, Debate Club Captain'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _sectionHeader('Optional Enhancers'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _pronounsController,
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Preferred pronouns'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _quoteController,
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Favorite study quote or motto'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _profileColor,
                        items: [null, ..._profileColors].map((c) => DropdownMenuItem(value: c, child: Text(c ?? 'Default'))).toList(),
                        onChanged: (v) => setState(() => _profileColor = v),
                        decoration: InputDecoration(
                          labelText: TranslationService.I.tr('Profile color theme'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _sectionHeader('Privacy Settings'),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _showPersonal,
                        onChanged: (v) => setState(() => _showPersonal = v),
                        title: const T('Show personal info (DOB / Age / Country)'),
                        activeThumbColor: Colors.purple.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      SwitchListTile(
                        value: _showAcademic,
                        onChanged: (v) => setState(() => _showAcademic = v),
                        title: const T('Show academic info'),
                        activeThumbColor: Colors.pink.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      SwitchListTile(
                        value: _showAvailability,
                        onChanged: (v) => setState(() => _showAvailability = v),
                        title: const T('Show availability'),
                        activeThumbColor: Colors.orange.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      SwitchListTile(
                        value: _allowRequests,
                        onChanged: (v) => setState(() => _allowRequests = v),
                        title: const T('Allow study requests'),
                        activeThumbColor: Colors.blue.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      SwitchListTile(
                        value: _schoolOnly,
                        onChanged: (v) => setState(() => _schoolOnly = v),
                        title: const T('Only allow school students to see profile'),
                        activeThumbColor: Colors.green.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _completion == 1.0
                              ? () {
                                  // TODO: Save all info
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: T('Profile saved!'), behavior: SnackBarBehavior.floating),
                                  );
                                  Navigator.pop(context);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _completion == 1.0
                                ? Colors.blue.shade700
                                : AppC.faint,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: Text(
                            _completion == 1.0 ? 'Save Profile' : 'Complete required fields',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppC.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.purple, Colors.pink, Colors.orange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppC.text,
          fontWeight: FontWeight.bold,
          fontSize: 17,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRadioGroup(String label, List<String> options, String? value, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: options.map((opt) => ChoiceChip(
            label: Text(opt),
            selected: value == opt,
            onSelected: (_) => onChanged(opt),
          )).toList(),
        ),
      ],
    );
  }
}

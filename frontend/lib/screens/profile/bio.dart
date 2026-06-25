// lib/screens/bio.dart
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/biodata.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class BioPage extends StatefulWidget {
  final BioData? existing; // pre-fill if user already filled once
  const BioPage({super.key, this.existing});

  @override
  State<BioPage> createState() => _BioPageState();
}

class _BioPageState extends State<BioPage> with TickerProviderStateMixin {
  final _dobCtrl          = TextEditingController();
  final _bioCtrl          = TextEditingController();
  final _schoolCtrl       = TextEditingController();
  final _achievementsCtrl = TextEditingController();
  final _pronounsCtrl     = TextEditingController();
  final _quoteCtrl        = TextEditingController();

  DateTime? _dob;
  int?      _age;
  String?   _country;
  String?   _year;
  String?   _major;
  String?   _studyStyle;
  String?   _studyTime;
  String?   _studyMode;
  bool      _availableForStudy = false;
  bool      _showPersonal      = true;
  bool      _showAcademic      = true;
  bool      _showAvailability  = true;
  bool      _allowRequests     = true;
  bool      _schoolOnly        = false;

  final List<String> _selectedSubjects = [];
  final List<String> _availableDays    = [];

  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  final _countries = [
    'Malaysia','Australia','United Kingdom','United States',
    'Singapore','India','Nigeria','South Africa','Canada','Other...',
  ];
  final _years = [
    'Year 7','Year 8','Year 9','Year 10','Year 11','Year 12','Year 13',
    'Grade 9','Grade 10','Grade 11','Grade 12',
    'Freshman','Sophomore','Junior','Senior',
  ];
  final _subjects = [
    'Mathematics','Physics','Chemistry','Biology','English',
    'History','Geography','Computer Science','Economics',
    'Business','Art','Music','Physical Education','Other',
  ];
  final _majors      = ['STEM','Arts','Commerce','Humanities','Other'];
  final _studyStyles = ['Quiet / Independent','Discussion / Group','Problem-solving'];
  final _studyTimes  = ['Morning','Afternoon','Evening'];
  final _studyModes  = ['Online','In-person','Both'];
  final _days        = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    // Pre-fill if returning to edit
    final e = widget.existing;
    if (e != null) {
      if (e.dob != null) {
        _dobCtrl.text = e.dob!;
        _age          = e.age;
      }
      _country          = e.country;
      _year             = e.year;
      _major            = e.major;
      _studyStyle       = e.studyStyle;
      _studyTime        = e.studyTime;
      _studyMode        = e.studyMode;
      _availableForStudy= e.availableForStudy;
      _showPersonal     = e.showPersonal;
      _showAcademic     = e.showAcademic;
      _showAvailability = e.showAvailability;
      _allowRequests    = e.allowRequests;
      _schoolOnly       = e.schoolOnly;
      _bioCtrl.text          = e.bio          ?? '';
      _schoolCtrl.text       = e.school       ?? '';
      _achievementsCtrl.text = e.achievements ?? '';
      _pronounsCtrl.text     = e.pronouns     ?? '';
      _quoteCtrl.text        = e.quote        ?? '';
      _selectedSubjects.addAll(e.subjects);
      _availableDays.addAll(e.availableDays);
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _dobCtrl.dispose(); _bioCtrl.dispose(); _schoolCtrl.dispose();
    _achievementsCtrl.dispose(); _pronounsCtrl.dispose(); _quoteCtrl.dispose();
    super.dispose();
  }

  void _pickDOB() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 16),
      firstDate: DateTime(now.year - 40),
      lastDate:  DateTime(now.year - 10),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kG2, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob           = picked;
        _dobCtrl.text  = DateFormat('dd MMMM yyyy').format(picked);
        _age           = now.year - picked.year -
            ((now.month < picked.month ||
                (now.month == picked.month && now.day < picked.day)) ? 1 : 0);
      });
    }
  }

  void _save() {
    HapticFeedback.mediumImpact();
    final data = BioData(
      dob:              _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
      age:              _age,
      country:          _country,
      year:             _year,
      major:            _major,
      school:           _schoolCtrl.text.trim().isEmpty ? null : _schoolCtrl.text.trim(),
      bio:              _bioCtrl.text.trim().isEmpty    ? null : _bioCtrl.text.trim(),
      achievements:     _achievementsCtrl.text.trim().isEmpty ? null : _achievementsCtrl.text.trim(),
      pronouns:         _pronounsCtrl.text.trim().isEmpty ? null : _pronounsCtrl.text.trim(),
      quote:            _quoteCtrl.text.trim().isEmpty  ? null : _quoteCtrl.text.trim(),
      studyStyle:       _studyStyle,
      studyTime:        _studyTime,
      studyMode:        _studyMode,
      subjects:         List.from(_selectedSubjects),
      availableDays:    List.from(_availableDays),
      availableForStudy:_availableForStudy,
      showPersonal:     _showPersonal,
      showAcademic:     _showAcademic,
      showAvailability: _showAvailability,
      allowRequests:    _allowRequests,
      schoolOnly:       _schoolOnly,
    );
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, height: 180,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kG2, _kG1],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Optional note
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: T(
                                  'All fields are optional. Fill in whatever you\'re comfortable sharing.',
                                  style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                                      color: AppC.text.withOpacity(0.85)),
                                )),
                              ]),
                            ),

                            _buildSection(icon: Icons.person_rounded,
                                title: 'Personal Info', color: _kG2,
                                child: _buildPersonalInfo()),
                            const SizedBox(height: 16),
                            _buildSection(icon: Icons.school_rounded,
                                title: 'Academic Info', color: _kG1,
                                child: _buildAcademicInfo()),
                            const SizedBox(height: 16),
                            _buildSection(icon: Icons.menu_book_rounded,
                                title: 'Study Preferences', color: _kG3,
                                child: _buildStudyPrefs()),
                            const SizedBox(height: 16),
                            _buildSection(icon: Icons.auto_awesome_rounded,
                                title: 'About Me', color: _kG4,
                                child: _buildAboutMe()),
                            const SizedBox(height: 16),
                            _buildSection(icon: Icons.lock_rounded,
                                title: 'Privacy Settings', color: _kG2,
                                child: _buildPrivacy()),
                            const SizedBox(height: 28),
                            _buildSaveButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T('Edit Bio', style: TextStyle(
                  fontFamily: 'Alfa', fontSize: 22,
                  color: AppC.text, fontWeight: FontWeight.bold,
                )),
                T('Everything here is optional',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          // Quick save button in header
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: T('Save', style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: AppC.text, fontSize: 14,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title,
      required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.1))),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(
                  fontFamily: 'Alfa', fontSize: 16, color: color)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('Date of Birth'),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _pickDOB,
        child: _Field(
          controller: _dobCtrl,
          hint: 'Select your date of birth',
          icon: Icons.calendar_today_rounded, iconColor: _kG2,
          readOnly: true,
          suffix: _dob != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _kG2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('Age: $_age', style: const TextStyle(
                      fontFamily: 'Momo', fontSize: 11,
                      fontWeight: FontWeight.bold, color: _kG2)),
                )
              : null,
        ),
      ),
      const SizedBox(height: 16),
      _Label('Country'),
      const SizedBox(height: 6),
      _Dropdown(value: _country, hint: 'Select your country',
          icon: Icons.public_rounded, iconColor: _kG2, items: _countries,
          onChanged: (v) => setState(() => _country = v)),
    ]);
  }

  Widget _buildAcademicInfo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('Year / Grade'),
      const SizedBox(height: 6),
      _Dropdown(value: _year, hint: 'Select your year',
          icon: Icons.grade_rounded, iconColor: _kG1, items: _years,
          onChanged: (v) => setState(() => _year = v)),
      const SizedBox(height: 16),
      _Label('Subjects'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _subjects.map((s) {
          final sel = _selectedSubjects.contains(s);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => sel ? _selectedSubjects.remove(s) : _selectedSubjects.add(s));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? _kG1 : AppC.card2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _kG1 : AppC.border, width: 1.5),
                boxShadow: sel ? [BoxShadow(color: _kG1.withOpacity(0.3),
                    blurRadius: 8, offset: const Offset(0, 2))] : [],
              ),
              child: Text(s, style: TextStyle(
                fontFamily: 'Momo', fontSize: 13,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? Colors.white : AppC.sub,
              )),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      _Label('Major / Stream'),
      const SizedBox(height: 6),
      _Dropdown(value: _major, hint: 'Select a major',
          icon: Icons.account_tree_rounded, iconColor: _kG1, items: _majors,
          onChanged: (v) => setState(() => _major = v)),
      const SizedBox(height: 16),
      _Label('School / Campus'),
      const SizedBox(height: 6),
      _Field(controller: _schoolCtrl, hint: 'Enter your school name',
          icon: Icons.location_city_rounded, iconColor: _kG1),
    ]);
  }

  Widget _buildStudyPrefs() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ChipGroup(label: 'Study Style', options: _studyStyles,
          selected: _studyStyle, color: _kG3,
          onSelected: (v) => setState(() => _studyStyle = v)),
      const SizedBox(height: 16),
      _ChipGroup(label: 'Preferred Time', options: _studyTimes,
          selected: _studyTime, color: _kG3,
          onSelected: (v) => setState(() => _studyTime = v)),
      const SizedBox(height: 16),
      _ChipGroup(label: 'Study Mode', options: _studyModes,
          selected: _studyMode, color: _kG3,
          onSelected: (v) => setState(() => _studyMode = v)),
      const SizedBox(height: 16),
      _Switch(
        label: 'Available for Study Buddy',
        subtitle: 'Show up in the Study Buddy finder',
        value: _availableForStudy, color: _kG3,
        onChanged: (v) => setState(() => _availableForStudy = v),
      ),
      if (_availableForStudy) ...[
        const SizedBox(height: 12),
        _Label('Available Days'),
        const SizedBox(height: 8),
        Row(
          children: _days.map((d) {
            final sel = _availableDays.contains(d);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => sel ? _availableDays.remove(d) : _availableDays.add(d));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _kG3 : AppC.card2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? _kG3 : AppC.border, width: 1.5),
                  ),
                  child: Center(child: Text(d, style: TextStyle(
                    fontFamily: 'Momo', fontSize: 11, fontWeight: FontWeight.bold,
                    color: sel ? Colors.white : AppC.faint,
                  ))),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ]);
  }

  Widget _buildAboutMe() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('Short Bio'),
      const SizedBox(height: 6),
      _Field(controller: _bioCtrl, hint: 'One sentence about yourself...',
          icon: Icons.edit_note_rounded, iconColor: _kG4,
          maxLines: 3, maxLength: 150),
      const SizedBox(height: 16),
      _Label('Achievements'),
      const SizedBox(height: 6),
      _Field(controller: _achievementsCtrl,
          hint: 'e.g. Top Math Student, Debate Club Captain...',
          icon: Icons.emoji_events_rounded, iconColor: _kG4, maxLines: 2),
      const SizedBox(height: 16),
      _Label('Preferred Pronouns'),
      const SizedBox(height: 6),
      _Field(controller: _pronounsCtrl, hint: 'e.g. she/her, they/them',
          icon: Icons.tag_rounded, iconColor: _kG4),
      const SizedBox(height: 16),
      _Label('Favourite Quote'),
      const SizedBox(height: 6),
      _Field(controller: _quoteCtrl, hint: 'Something that inspires you...',
          icon: Icons.format_quote_rounded, iconColor: _kG4, maxLines: 2),
    ]);
  }

  Widget _buildPrivacy() {
    return Column(children: [
      _Switch(
        label: 'Show Personal Info',
        subtitle: 'DOB, age, country visible on your profile',
        value: _showPersonal, color: _kG2,
        onChanged: (v) => setState(() => _showPersonal = v),
      ),
      _Switch(
        label: 'Show Academic Info',
        subtitle: 'Year, subjects and school visible',
        value: _showAcademic, color: _kG2,
        onChanged: (v) => setState(() => _showAcademic = v),
      ),
      _Switch(
        label: 'Show Study Availability',
        subtitle: 'Others can see when you\'re available',
        value: _showAvailability, color: _kG2,
        onChanged: (v) => setState(() => _showAvailability = v),
      ),
      _Switch(
        label: 'Allow Study Requests',
        subtitle: 'Others can send you study invites',
        value: _allowRequests, color: _kG2,
        onChanged: (v) => setState(() => _allowRequests = v),
      ),
      _Switch(
        label: 'School Students Only',
        subtitle: 'Only Taylors students can view your profile',
        value: _schoolOnly, color: _kG2, showDivider: false,
        onChanged: (v) => setState(() => _schoolOnly = v),
      ),
      // Live preview of what's visible
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kG2.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kG2.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            T('What others will see on your profile:',
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 12, color: _kG2)),
            const SizedBox(height: 10),
            ...[
              ('Personal info (DOB, age, country)', _showPersonal),
              ('Academic info (year, subjects, school)', _showAcademic),
              ('Study availability', _showAvailability),
              ('Study request button', _allowRequests),
            ].map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(item.$2 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: item.$2 ? Colors.green.shade600 : Colors.red.shade400, size: 16),
                const SizedBox(width: 8),
                Text(item.$1, style: TextStyle(
                  fontFamily: 'Momo', fontSize: 12,
                  color: item.$2 ? const Color(0xFF1A1A2E) : AppC.faint,
                  decoration: item.$2 ? null : TextDecoration.lineThrough,
                )),
              ]),
            )),
          ],
        ),
      ),
    ]);
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _save,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kG1, _kG2, _kG3, _kG4],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _kG2.withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              T('Save Profile', style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: AppC.text, fontSize: 16,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);
  @override
  Widget build(BuildContext context) => Text(label, style: TextStyle(
    fontFamily: 'Arch', fontWeight: FontWeight.bold,
    fontSize: 13, color: AppC.text,
  ));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String   hint;
  final IconData icon;
  final Color    iconColor;
  final bool     readOnly;
  final int      maxLines;
  final int?     maxLength;
  final Widget?  suffix;

  const _Field({
    required this.controller, required this.hint,
    required this.icon, required this.iconColor,
    this.readOnly = false, this.maxLines = 1,
    this.maxLength, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppC.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 12, top: maxLines > 1 ? 14 : 0),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller, readOnly: readOnly,
              maxLines: maxLines, maxLength: maxLength,
              style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                  color: AppC.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppC.faint, fontFamily: 'Momo'),
                border: InputBorder.none, counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          if (suffix != null)
            Padding(padding: const EdgeInsets.only(right: 12), child: suffix!),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String?          value;
  final String           hint;
  final IconData         icon;
  final Color            iconColor;
  final List<String>     items;
  final void Function(String?) onChanged;

  const _Dropdown({required this.value, required this.hint, required this.icon,
      required this.iconColor, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppC.border, width: 1.5),
      ),
      child: Row(children: [
        Padding(padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, color: iconColor, size: 20)),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value, isExpanded: true,
            decoration: const InputDecoration(border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
            hint: Text(hint, style: TextStyle(color: AppC.faint,
                fontFamily: 'Momo', fontSize: 14)),
            style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                color: AppC.text),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: onChanged,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppC.faint),
          ),
        ),
      ]),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final String       label;
  final List<String> options;
  final String?      selected;
  final Color        color;
  final void Function(String) onSelected;

  const _ChipGroup({required this.label, required this.options,
      required this.selected, required this.color, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label(label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: options.map((opt) {
          final sel = selected == opt;
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onSelected(opt); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? color : AppC.card2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? color : AppC.border, width: 1.5),
                boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 2))] : [],
              ),
              child: Text(opt, style: TextStyle(
                fontFamily: 'Momo', fontSize: 13,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? Colors.white : AppC.sub,
              )),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

class _Switch extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final bool     value;
  final Color    color;
  final void Function(bool) onChanged;
  final bool     showDivider;

  const _Switch({required this.label, required this.subtitle, required this.value,
      required this.color, required this.onChanged, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 14, color: AppC.text)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: AppC.faint)),
          ])),
          Switch(
            value: value, onChanged: onChanged,
            activeThumbColor: Colors.white, activeTrackColor: color,
            inactiveThumbColor: Colors.white, inactiveTrackColor: AppC.border,
          ),
        ]),
      ),
      if (showDivider) Divider(height: 1, color: AppC.card2),
    ]);
  }
}
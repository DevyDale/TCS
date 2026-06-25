import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/services/notification_Service.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'session_keys.dart';
import '../dashboard/dashboard_screen.dart';
import '../terms_of_service_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

Color get _kInk => AppC.text;
const _kBg = Color(0xFFF5F6FA);

class LoginIdScreen extends StatefulWidget {
  final String role; // 'student' | 'teaching_staff'

  const LoginIdScreen({super.key, required this.role});

  @override
  State<LoginIdScreen> createState() => _LoginIdScreenState();
}

class _LoginIdScreenState extends State<LoginIdScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _idFocus = FocusNode();
  final _dobFocus = FocusNode();
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _eulaAccepted = false;
  bool _dobFocused = false;

  late final AnimationController _entryCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _floatAnim;

  final _authService = AuthService();

  String get _formattedDate {
    final d = _selectedDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool get _isStudent => widget.role == 'student';

  List<Color> get _roleGradient => _isStudent
      ? const [Color(0xFF4FC3F7), Color(0xFF0288D1)]
      : const [Color(0xFF81C784), Color(0xFF2E7D32)];

  Color get _accentColor =>
      _isStudent ? const Color(0xFF0288D1) : const Color(0xFF388E3C);

  String get _roleLabel => _isStudent ? 'Student' : 'Staff';

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _scaleAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _floatAnim = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _dobFocus.addListener(() {
      if (mounted) setState(() => _dobFocused = _dobFocus.hasFocus);
    });

    _entryCtrl.forward();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _idCtrl.dispose();
    _dobCtrl.dispose();
    _idFocus.dispose();
    _dobFocus.dispose();
    super.dispose();
  }

  // ── SECTION 1 FIX ────────────────────────────────────────
  // Same proactive-refresh pattern as the splash. If the user
  // somehow lands on this screen with a still-valid session
  // (e.g. they reopened the app mid-flight), we refresh the
  // token first so the dashboard's first call hits a fresh
  // token, then send them straight through.
  Future<void> _checkAuthStatus() async {
    await ApiService.instance.initialize();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(SessionKeys.accessToken);
    final fullName = prefs.getString(SessionKeys.fullName);
    final preferredName = prefs.getString(SessionKeys.preferredName);
    final role = prefs.getString(SessionKeys.role);

    if (token != null &&
        token.isNotEmpty &&
        fullName != null &&
        fullName.isNotEmpty &&
        mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        _fadeRoute(
          DashboardScreen(
            fullName: fullName,
            preferredName: preferredName ?? '',
            role: role ?? '',
          ),
        ),
        (r) => false,
      );
    }
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(_isStudent ? 2006 : 1990),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: _accentColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}'
            '/${picked.month.toString().padLeft(2, '0')}'
            '/${picked.year}';
      });
    }
  }

  // ── DOB input — typeable DD/MM/YYYY with calendar fallback ─
  Widget _buildDobField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _dobFocused ? _accentColor : Colors.grey.shade200,
          width: _dobFocused ? 2 : 1.5,
        ),
        boxShadow: _dobFocused
            ? [
                BoxShadow(
                  color: _accentColor.withOpacity(0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: _dobCtrl,
        focusNode: _dobFocus,
        keyboardType: TextInputType.number,
        inputFormatters: [_DobInputFormatter()],
        style: TextStyle(fontFamily: 'Momo', fontSize: 15, color: _kInk),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: TranslationService.I.tr('DD/MM/YYYY'),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Momo'),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _roleGradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cake_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.calendar_month_rounded,
              color: _accentColor,
              size: 22,
            ),
            onPressed: _selectDate,
            tooltip: TranslationService.I.tr('Pick from calendar'),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          errorStyle: const TextStyle(fontFamily: 'Momo'),
        ),
        onChanged: (v) {
          final parsed = _parseDob(v);
          if (parsed != _selectedDate) {
            setState(() => _selectedDate = parsed);
          }
        },
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter your date of birth';
          if (_parseDob(v) == null) {
            return 'Enter a valid date (DD/MM/YYYY)';
          }
          return null;
        },
      ),
    );
  }

  /// Parses a DD/MM/YYYY string into a DateTime. Returns null if
  /// malformed, if any component is out of range, if the day doesn't
  /// exist in that month (e.g. 31/02), or if the date is in the future.
  DateTime? _parseDob(String text) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 1900 || year > DateTime.now().year) return null;
    final dt = DateTime(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) return null;
    if (dt.isAfter(DateTime.now())) return null;
    return dt;
  }

  Future<void> _handleLogin() async {
    if (!_eulaAccepted) {
      HapticFeedback.heavyImpact();
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: _EulaToast(),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack('Please select your date of birth', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      if (_isStudent) {
        await _authService.verifyStudent(
          studentId: _idCtrl.text.trim(),
          dateOfBirth: _formattedDate,
        );
      } else {
        await _authService.verifyStaff(
          staffId: _idCtrl.text.trim(),
          dateOfBirth: _formattedDate,
        );
      }

      final result = await _authService.loginWithId(
        userId: _idCtrl.text.trim(),
        dateOfBirth: _formattedDate,
        role: _isStudent ? 'student' : 'teaching_staff',
      );

      // Start the notifications service immediately on a fresh login so
      // the bell badge is live by the time the dashboard renders.
      await NotificationService.instance.bootstrap();

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          _fadeRoute(
            DashboardScreen(
              fullName: result.name,
              preferredName: result.preferredName,
              role: result.isStudent ? 'Student' : 'Staff',
            ),
          ),
          (r) => false,
        );
      }
    } on AuthException catch (e) {
      _showSnack('False Credentials', isError: true);
    } catch (e) {
      _showSnack('Something went wrong. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (isError) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: _AnimatedToast(
          message: msg,
          icon: isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_rounded,
          iconGradient: isError
              ? const [Color(0xFFFF5858), Color(0xFFFF8A8A)]
              : const [Color(0xFF22C55E), Color(0xFF4ADE80)],
          shake: isError,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  PageRoute _fadeRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (_, anim, __) => screen,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            // ── Gradient header (runs under the status bar) ──────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.42,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _roleGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(44),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.30),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(right: -50, top: -50, child: _blob(200, 0.08)),
                    Positioned(left: -30, bottom: 40, child: _blob(130, 0.06)),
                    Positioned(right: 40, bottom: 80, child: _blob(46, 0.10)),
                  ],
                ),
              ),
            ),

            // ── Scrolling content ────────────────────────────────
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // ── Back button ────────────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── Floating logo (Hero from role tile) ──
                        Center(
                          child: AnimatedBuilder(
                            animation: _floatAnim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, _floatAnim.value),
                              child: child,
                            ),
                            child: ScaleTransition(
                              scale: _scaleAnim,
                              child: Hero(
                                tag: 'role_icon_${widget.role}',
                                child: _buildRoleIcon(),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── Title ───────────────────────────────
                        SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            children: [
                              T(
                                'Welcome Back!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Alfa',
                                  fontSize: 30,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              T(
                                'Sign in with your ID & date of birth',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Momo',
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        // ── Form card ───────────────────────────
                        SlideTransition(
                          position: _slideAnim,
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.07),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(child: _buildRolePill()),
                                const SizedBox(height: 22),

                                // ID field (numeric keyboard)
                                _FormLabel(
                                  label: '$_roleLabel ID',
                                  color: _accentColor,
                                ),
                                const SizedBox(height: 8),
                                _LoginField(
                                  controller: _idCtrl,
                                  focusNode: _idFocus,
                                  hint: 'Enter your $_roleLabel ID',
                                  icon: Icons.badge_rounded,
                                  accentColor: _accentColor,
                                  gradient: _roleGradient,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Please enter your ID'
                                      : null,
                                ),

                                const SizedBox(height: 20),

                                // DOB field
                                _FormLabel(
                                  label: 'Date of Birth',
                                  color: _accentColor,
                                ),
                                const SizedBox(height: 8),
                                _buildDobField(),

                                const SizedBox(height: 20),

                                // Login button
                                _LoginButton(
                                  isLoading: _isLoading,
                                  gradient: _roleGradient,
                                  onTap: _handleLogin,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        _buildEulaRow(),

                        const SizedBox(height: 18),

                        // ── Security note ───────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 13,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 6),
                            T(
                              'Your credentials are securely encrypted',
                              style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  Widget _buildRolePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _accentColor.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isStudent ? Icons.school_rounded : Icons.badge_rounded,
            color: _accentColor,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            '$_roleLabel account',
            style: TextStyle(
              fontFamily: 'Arch',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _accentColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEulaRow() {
    return GestureDetector(
      onTap: () => setState(() => _eulaAccepted = !_eulaAccepted),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _eulaAccepted ? _accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _eulaAccepted ? _accentColor : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: _eulaAccepted
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12.5,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service & EULA',
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
            child: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: _accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleIcon() {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.16),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
      ),
      child: Center(
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _roleGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            _isStudent ? Icons.school_rounded : Icons.badge_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }
}

// ── Shared login sub-widgets ──────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _FormLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Arch',
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: color,
      ),
    );
  }
}

class _LoginField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradient;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;

  const _LoginField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.accentColor,
    required this.gradient,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
  });

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? widget.accentColor : Colors.grey.shade200,
          width: _focused ? 2 : 1.5,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        style: TextStyle(fontFamily: 'Momo', fontSize: 15, color: _kInk),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: widget.hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Momo'),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: widget.gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 18),
          ),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          errorStyle: const TextStyle(fontFamily: 'Momo'),
        ),
        validator: widget.validator,
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _LoginButton({
    required this.isLoading,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [Colors.grey.shade300, Colors.grey.shade400]
                : gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: gradient.last.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    T(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EulaToast extends StatefulWidget {
  const _EulaToast();

  @override
  State<_EulaToast> createState() => _EulaToastState();
}

class _EulaToastState extends State<_EulaToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _iconScale;
  late final Animation<double> _shake;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _iconScale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.12), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 13),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.07), weight: 13),
      TweenSequenceItem(tween: Tween(begin: -0.07, end: 0.0), weight: 12),
    ]).animate(_c);
    _contentFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _c,
            curve: const Interval(0.15, 0.6, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1D2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Transform.rotate(
              angle: _shake.value,
              child: Transform.scale(scale: _iconScale.value, child: child),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFF7971E), Color(0xFFFFC061)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T(
                      'One quick thing',
                      style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    T(
                      'Please accept the Terms of Service & EULA to continue.',
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedToast extends StatefulWidget {
  final String? title;
  final String message;
  final IconData icon;
  final List<Color> iconGradient;
  final bool shake;

  const _AnimatedToast({
    this.title,
    required this.message,
    required this.icon,
    required this.iconGradient,
    this.shake = true,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _iconScale;
  late final Animation<double> _shakeAnim;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _iconScale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.12), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 13),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.07), weight: 13),
      TweenSequenceItem(tween: Tween(begin: -0.07, end: 0.0), weight: 12),
    ]).animate(_c);
    _contentFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _c,
            curve: const Interval(0.15, 0.6, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = widget.title != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1D2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Transform.rotate(
              angle: widget.shake ? _shakeAnim.value : 0.0,
              child: Transform.scale(scale: _iconScale.value, child: child),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: widget.iconGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: hasTitle
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title!,
                            style: const TextStyle(
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 12,
                              height: 1.3,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.message,
                        style: const TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DobInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < truncated.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(truncated[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

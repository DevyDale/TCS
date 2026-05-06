import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tcs_app/screens/dashboard/dashboard_screen.dart';
import '../../services/auth_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

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
  final _idFocus = FocusNode();
  DateTime? _selectedDate;
  bool _isLoading = false;

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
        vsync: this, duration: const Duration(milliseconds: 900));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entryCtrl, curve: Curves.easeOutCubic));
    _scaleAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl.forward();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _idCtrl.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final fullName = prefs.getString('fullName');
    final preferredName = prefs.getString('preferredName');
    final role = prefs.getString('role');
    if (token != null &&
        token.isNotEmpty &&
        fullName != null &&
        fullName.isNotEmpty &&
        mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        _fadeRoute(DashboardScreen(
          fullName: fullName,
          preferredName: preferredName ?? '',
          role: role ?? '',
        )),
        (r) => false,
      );
    }
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _handleLogin() async {
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
          studentId:   _idCtrl.text.trim(),
          dateOfBirth: _formattedDate,
        );
      } else {
        await _authService.verifyStaff(
          staffId:     _idCtrl.text.trim(),
          dateOfBirth: _formattedDate,
        );
      }

      final result = await _authService.loginWithId(
        userId:      _idCtrl.text.trim(),
        dateOfBirth: _formattedDate,
        role:        _isStudent ? 'student' : 'teaching_staff',
      );

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          _fadeRoute(DashboardScreen(
            fullName:      result.name,
            preferredName: result.preferredName,
            role:          result.isStudent ? 'Student' : 'Staff',
          )),
          (r) => false,
        );
      }
    } on AuthException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Something went wrong. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
            ),
          ],
        ),
        backgroundColor: isError ? _kG4 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          // ── Background arc ──────────────────────────────────
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
                  bottom: Radius.circular(40),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: 30,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ── Back button ─────────────────────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Floating logo ───────────────────────
                      Center(
                        child: AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: child,
                          ),
                          child: ScaleTransition(
                            scale: _scaleAnim,
                            child: _buildRoleIcon(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Title ───────────────────────────────
                      SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            Text(
                              'Welcome Back!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Alfa',
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_roleLabel · ID & Date of Birth login',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: size.height * 0.05),

                      // ── Form card ───────────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ID field
                            _FormLabel(
                                label: '$_roleLabel ID',
                                color: _accentColor),
                            const SizedBox(height: 8),
                            _LoginField(
                              controller: _idCtrl,
                              focusNode: _idFocus,
                              hint: 'Enter your $_roleLabel ID',
                              icon: Icons.badge_rounded,
                              accentColor: _accentColor,
                              gradient: _roleGradient,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Please enter your ID'
                                      : null,
                            ),

                            const SizedBox(height: 20),

                            // DOB field
                            _FormLabel(
                                label: 'Date of Birth',
                                color: _accentColor),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _selectDate,
                              child: _DateField(
                                date: _selectedDate,
                                accentColor: _accentColor,
                                gradient: _roleGradient,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Login button
                            _LoginButton(
                              isLoading: _isLoading,
                              gradient: _roleGradient,
                              onTap: _handleLogin,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Security note ───────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(
                            'Your credentials are securely encrypted',
                            style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleIcon() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
            color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        _isStudent ? Icons.school_rounded : Icons.badge_rounded,
        color: Colors.white,
        size: 42,
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

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradient;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _LoginField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.accentColor,
    required this.gradient,
    this.validator,
    this.obscure      = false,   // ← fix: was missing, caused the error
    this.keyboardType = null,    // ← fix: was missing, caused the error
    this.suffix       = null,    // ← fix: was missing, caused the error
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
            fontFamily: 'Momo',
            fontSize: 15,
            color: Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.grey.shade400, fontFamily: 'Momo'),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          errorStyle: const TextStyle(fontFamily: 'Momo'),
        ),
        validator: validator,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? date;
  final Color accentColor;
  final List<Color> gradient;

  const _DateField({
    required this.date,
    required this.accentColor,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = date == null
        ? null
        : '${date!.day.toString().padLeft(2, '0')} / '
            '${date!.month.toString().padLeft(2, '0')} / '
            '${date!.year}';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: date != null ? accentColor : Colors.grey.shade200,
          width: date != null ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: Colors.white, size: 17),
          ),
          Expanded(
            child: Text(
              formatted ?? 'Select your date of birth',
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 15,
                color: date != null
                    ? const Color(0xFF1A1A2E)
                    : Colors.grey.shade400,
              ),
            ),
          ),
          if (date != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.check_rounded,
                    color: accentColor, size: 14),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade400),
            ),
        ],
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
                    Text(
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
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
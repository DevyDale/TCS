// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tcs_app/screens/splash_screen.dart';

import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/app_settings.dart';
import 'package:tcs_app/services/app_localisations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Silently refresh saved token on startup (keeps user logged in)
  await ApiService().initialize();

  // Load persisted theme + language BEFORE first frame — no flash on startup
  await AppSettings().load();

  runApp(const TCSApp());
}

// ─────────────────────────────────────────────────────────────
// ROOT APP — StatefulWidget so it can rebuild when theme/lang
// changes via AppSettings (ChangeNotifier)
// ─────────────────────────────────────────────────────────────

class TCSApp extends StatefulWidget {
  const TCSApp({super.key});
  @override
  State<TCSApp> createState() => _TCSAppState();
}

class _TCSAppState extends State<TCSApp> {
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_rebuild);
  }

  @override
  void dispose() {
    _settings.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    // AppL10nProvider wraps everything so every screen gets the right language
    return AppL10nProvider(
      languageCode: _settings.lang,
      child: GetMaterialApp(
        title: 'Taylors College',
        debugShowCheckedModeBanner: false,
        defaultTransition: Transition.cupertino,
        transitionDuration: const Duration(milliseconds: 350),

        // ── Theme (persisted — user's choice survives restarts) ──
        themeMode: _settings.themeMode,
        theme:     _buildLightTheme(),
        darkTheme: _buildDarkTheme(),

        // ── Locale (persisted — switches ENTIRE app language) ────
        locale: _settings.locale,
        supportedLocales: const [
          Locale('en'),
          Locale('ms'),
          Locale('zh'),
          Locale('ta'),
          Locale('ar'),
        ],

        // ── REQUIRED: delegates so Material/Cupertino widgets work
        // in ALL locales (without these, RefreshIndicator, Scaffold,
        // SnackBar etc. crash when locale is anything other than 'en')
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],

        home: const SplashScreen(),
      ),
    );
  }

  // ── Light theme ───────────────────────────────────────────

  ThemeData _buildLightTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E54E9),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Arch',
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF8E54E9), width: 2),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      selectedItemColor: Color(0xFF8E54E9),
      unselectedItemColor: Color(0xFFB0B0B0),
      selectedLabelStyle: TextStyle(
        fontFamily: 'Momo',
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: 'Momo', fontSize: 11),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),

    fontFamily: 'Momo',
  );

  // ── Dark theme ────────────────────────────────────────────

  ThemeData _buildDarkTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E54E9),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F14),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1A1A24),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Arch',
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A24),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A2A38)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6DD5FA), width: 2),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1A1A24),
      elevation: 0,
      selectedItemColor: Color(0xFF6DD5FA),
      unselectedItemColor: Color(0xFF555566),
      selectedLabelStyle: TextStyle(
        fontFamily: 'Momo',
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: 'Momo', fontSize: 11),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),

    fontFamily: 'Momo',
  );
}
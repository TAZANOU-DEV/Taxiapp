import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'notification.dart'; // Contient NotificationService & navigatorKey
import 'chat_page.dart';
import 'notification_page.dart';
import 'admin_dashboard.dart';

void main() async {
  // 1. Assure la liaison obligatoire avec le moteur natif de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialisation sécurisée de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialisé avec succès !");
  } catch (e) {
    print("⚠️ Erreur d'initialisation Firebase capturée : $e");
  }

  // 3. Initialisation sécurisée du service de notifications
  try {
    await NotificationService.initialize();
    print("✅ Service de notifications initialisé avec succès !");
  } catch (e) {
    print("⚠️ Erreur d'initialisation des Notifications capturée : $e");
  }

  // 4. Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('app_theme') ?? 'dark';
  final savedLanguage = prefs.getString('app_language') ?? 'English';

  // 5. Lancement final de l'interface utilisateur
  runApp(MyApp(
    initialTheme: savedTheme,
    initialLanguage: savedLanguage,
  ));
}

class MyApp extends StatefulWidget {
  final String initialTheme;
  final String initialLanguage;

  const MyApp({
    super.key,
    this.initialTheme = 'dark',
    this.initialLanguage = 'English',
  });

  @override
  State<MyApp> createState() => MyAppState();

  /// Global state accessor for theme/language changes
  static MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<MyAppState>();
  }
}

class MyAppState extends State<MyApp> {
  late String currentTheme;
  late String currentLanguage;

  @override
  void initState() {
    super.initState();
    currentTheme = widget.initialTheme;
    currentLanguage = widget.initialLanguage;
  }

  void setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme);
    setState(() {
      currentTheme = theme;
    });
  }

  void setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', language);
    setState(() {
      currentLanguage = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = currentTheme == 'dark';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taxi Safety App',
      navigatorKey: navigatorKey, // Global navigator key for overlay dialogs
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primaryColor: Colors.yellow,
        scaffoldBackgroundColor: isDark ? Colors.black : Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: isDark ? Colors.black : Colors.white,
          foregroundColor: isDark ? Colors.yellow : Colors.black,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      // Routes de navigation
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const HomePage(),
        '/admin': (_) => const AdminDashboard(),
        '/chat': (_) => const ChatPage(),
        '/notifications': (_) => const NotificationPage(),
      },
      initialRoute: '/login',
    );
  }
}

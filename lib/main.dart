import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'notification.dart'; // Contient votre NotificationService
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
    // L'application ne crash plus, l'erreur est juste écrite dans la console
  }

  // 3. Initialisation sécurisée du service de notifications
  try {
    await NotificationService.initialize();
    print("✅ Service de notifications initialisé avec succès !");
  } catch (e) {
    print("⚠️ Erreur d'initialisation des Notifications capturée : $e");
    // Empêche le crash si un canal système Android ou une permission manque
  }

  // 4. Lancement final de l'interface utilisateur
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taxi Safety App',
      theme: ThemeData(
        primaryColor: Colors.yellow,
      ),
      // Vos routes de navigation
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

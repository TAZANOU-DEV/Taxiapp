import 'package:flutter/material.dart';

import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'notification.dart';
import 'chat_page.dart';
import 'notification_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taxi Safety App',
      theme: ThemeData(primaryColor: Colors.yellow),

      // In main.dart
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const HomePage(),
        '/chat': (_) => const ChatPage(),
        '/notifications': (_) => const NotificationPage(),
      },
      initialRoute: '/login',
    );
  }
}

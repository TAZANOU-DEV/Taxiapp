import 'package:flutter/material.dart';

// Import your pages
import 'login_page.dart';
import 'register_page.dart';

void main() {
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
      // Define routes
      routes: {
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
      // App starts here
      initialRoute: '/',
    );
  }
}

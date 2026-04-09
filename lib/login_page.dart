import 'package:flutter/material.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator, use 10.0.2.2 for localhost
  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _matriculeError;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMatricule = prefs.getString('matricule');
    final savedPassword = prefs.getString('password');
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember && savedMatricule != null && savedPassword != null) {
      _matriculeController.text = savedMatricule;
      _passwordController.text = savedPassword;
      _rememberMe = true;
    }
  }

  // Enhanced matricule validation with specific error messages
  String? _validateMatricule(String matricule) {
    if (matricule.isEmpty) {
      return 'Taxi Matricule is required';
    }

    List<String> parts = matricule.split(' ');
    if (parts.length != 3) {
      return 'Format must be: XX 1234 Y (3 parts separated by spaces)\nExample: CE 4587 A';
    }

    String region = parts[0];
    String number = parts[1];
    String letter = parts[2];

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
      return 'Region code must be exactly 2 uppercase letters (e.g., CE, LT, OU)';
    }

    if (!RegExp(r'^\d{3,4}$').hasMatch(number)) {
      return 'Number must be 3 or 4 digits (e.g., 123, 1234)';
    }

    if (!RegExp(r'^[A-Z]$').hasMatch(letter)) {
      return 'Last part must be 1 uppercase letter (e.g., A, B, C)';
    }

    return null; // Valid matricule
  }

  void _validateAndLogin() async {
    final matricule = _matriculeController.text.trim();

    if (matricule.isEmpty) {
      setState(() {
        _matriculeError = 'Taxi Matricule is required';
      });
      return;
    }

    String? matriculeValidation = _validateMatricule(matricule);
    if (matriculeValidation != null) {
      setState(() {
        _matriculeError = matriculeValidation;
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password is required')),
      );
      return;
    }

    // Make API call to backend
    try {
      print('Attempting login with matricule: $matricule');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'matricule': matricule,
          'password': _passwordController.text,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // Save token and user data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('user', jsonEncode(data['user']));

          // Save credentials if remember me is checked
          if (_rememberMe) {
            await prefs.setString('matricule', matricule);
            await prefs.setString('password', _passwordController.text);
            await prefs.setBool('remember_me', true);
          } else {
            // Clear saved data if not remembering
            await prefs.remove('matricule');
            await prefs.remove('password');
            await prefs.setBool('remember_me', false);
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Login failed')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server error. Please try again.')),
        );
      }
    } catch (e) {
      print('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Taximan Login",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: _matriculeController,
                decoration: InputDecoration(
                  labelText: "Taxi Matricule",
                  hintText: "e.g., CE 4587 A",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  errorText: _matriculeError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                onChanged: (_) {
                  if (_matriculeError != null) {
                    setState(() {
                      _matriculeError = null;
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text("Remember me"),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                "Format: Region Code (2 letters) + Space + Number (3-4 digits) + Space + Letter",
                style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.7)),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: _validateAndLogin,
                  child: const Text(
                    "LOGIN",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Register",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _matriculeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

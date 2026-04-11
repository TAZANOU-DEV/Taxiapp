import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    return 'http://10.0.2.2:3000'; // Android emulator local backend
  }

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _matriculeError;

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

  void _validateAndRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final matricule = _matriculeController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate all fields
    if (name.isEmpty) {
      _showError('Full Name is required');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showError('Valid email is required');
      return;
    }

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

    if (phone.isEmpty || phone.length < 9) {
      _showError('Valid phone number is required');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    // Make API call to backend
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': name,
          'email': email,
          'password': password,
          'role': 'driver',
          'phone': phone,
          'vehicleModel': 'Taxi',
          'licensePlate': matricule,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _showSuccess('Registration successful! Welcome.');
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          });
        } else {
          _showError(data['error'] ?? 'Registration failed');
        }
      } else {
        _showError('Server error. Please try again.');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
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
                "Taximan Registration",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
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
              const SizedBox(height: 10),
              Text(
                "Format: Region Code (2 letters) + Space + Number (3-4 digits) + Space + Letter\nExample: CE 4587 A, LT 9087 D",
                style: TextStyle(
                    fontSize: 11, color: Colors.black.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password (min 6 characters)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: _validateAndRegister,
                  child: const Text(
                    "REGISTER",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Login",
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
    _nameController.dispose();
    _emailController.dispose();
    _matriculeController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

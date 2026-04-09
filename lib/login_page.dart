import 'package:flutter/material.dart';
import 'register_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _matriculeError;

  // Cameroon taxi matricule regex pattern: XX 1234 Y
  // Region code (2 letters) + Space + Number (3-4 digits) + Space + Letter
  bool _isValidMatricule(String matricule) {
    final RegExp cameroonPattern = RegExp(r'^[A-Z]{2}\s\d{3,4}\s[A-Z]$');
    return cameroonPattern.hasMatch(matricule);
  }

  void _validateAndLogin() {
    final matricule = _matriculeController.text.trim();

    if (matricule.isEmpty) {
      setState(() {
        _matriculeError = 'Taxi Matricule is required';
      });
      return;
    }

    if (!_isValidMatricule(matricule)) {
      setState(() {
        _matriculeError = 'Invalid format. Use: XX 1234 Y\nExample: CE 4587 A';
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password is required')),
      );
      return;
    }

    // Proceed with login
    setState(() {
      _matriculeError = null;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
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

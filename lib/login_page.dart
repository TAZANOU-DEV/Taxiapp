import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
// Social login packages caused compatibility issues in the current build.
// Stubbing social login flows for now to allow the app to compile.
// If you want social sign-in, re-enable and adapt these imports to the
// package versions you're using.
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:convert';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'admin_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String get baseUrl {
    return 'https://taxiapp-back.vercel.app';
  }

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _emailError;
  bool _rememberMe = false;
  bool _isAdminLogin = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email') ?? prefs.getString('matricule');
    final savedPassword = prefs.getString('password');
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember && savedEmail != null && savedPassword != null) {
      _emailController.text = savedEmail;
      _passwordController.text = savedPassword;
      _rememberMe = true;
    }
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _handleSocialLogin(
      String provider, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/social-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'provider': provider, ...payload}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('user', jsonEncode(data['user']));

          final userRole = data['user']['role'];
          if (userRole == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          _showSnackBar(data['error'] ?? 'Social login failed.');
        }
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Server error. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Social auth failed: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    // Stubbed: Google sign-in is disabled to avoid compile-time
    // incompatibilities with the installed google_sign_in package.
    _showSnackBar('Google login is not configured in this build.');
  }

  Future<void> _loginWithFacebook() async {
    // Stubbed: Facebook sign-in is disabled to avoid compile-time
    // incompatibilities with the installed flutter_facebook_auth package.
    _showSnackBar('Facebook login is not configured in this build.');
  }

  void _validateAndLogin() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        _emailError = 'Enter a valid email';
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
      print('Attempting login with email: $email');
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
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

          final user = data['user'] as Map<String, dynamic>?;
          final username =
              user?['username']?.toString() ?? email.split('@').first;
          final taxiId = user?['taxiId']?.toString() ?? 'Unknown';
          final userId = user != null && user['id'] != null
              ? int.tryParse(user['id'].toString())
              : null;

          await prefs.setString('user_name', username);
          await prefs.setString(
              'user_email', data['user']['email']?.toString() ?? email);
          await prefs.setString('taxi_id', taxiId);
          if (userId != null) {
            await prefs.setInt('user_id', userId);
          }

          // Save credentials if remember me is checked
          if (_rememberMe) {
            await prefs.setString('email', email);
            await prefs.setString('password', _passwordController.text);
            await prefs.setBool('remember_me', true);
          } else {
            // Clear saved data if not remembering
            await prefs.remove('email');
            await prefs.remove('matricule'); // backward-compat cleanup
            await prefs.remove('password');
            await prefs.setBool('remember_me', false);
          }

          // Navigate based on user role
          final userRole = data['user']['role'];
          if (userRole == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  userName: username,
                  taxiId: taxiId,
                ),
              ),
            );
          }
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
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),

              const SizedBox(height: 10),

              // Admin login toggle - use Wrap to avoid RenderFlex overflow on small screens
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text("Driver Login",
                      style: TextStyle(color: Colors.black)),
                  Switch(
                    value: _isAdminLogin,
                    onChanged: (value) {
                      setState(() {
                        _isAdminLogin = value;
                      });
                    },
                    activeThumbColor: Colors.black,
                  ),
                  const Text("Admin Login",
                      style: TextStyle(color: Colors.black)),
                ],
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  hintText: "e.g., driver@taxiapp.com",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  errorText: _emailError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                onChanged: (_) {
                  if (_emailError != null) {
                    setState(() {
                      _emailError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
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
                  const Text("Remember me",
                      style: TextStyle(color: Colors.black)),
                ],
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordPage(),
                    ),
                  );
                },
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Or continue with',
                style: TextStyle(fontSize: 14, color: Colors.black),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                        ),
                        onPressed: _loginWithGoogle,
                        child: const Text('Google'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                        ),
                        onPressed: _loginWithFacebook,
                        child: const Text('Facebook'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: Colors.black)),
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

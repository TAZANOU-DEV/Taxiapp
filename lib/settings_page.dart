import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Real user data from SharedPreferences/backend
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String userTaxiId = '';
  String userMatricule = '';
  String userRole = 'driver';
  int? userId;
  String? authToken;

  // Theme & Language
  bool _isDarkMode = true;
  String _selectedLanguage = 'English';
  bool _isLoading = true;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  final String baseUrl = 'https://taxiapp-back.vercel.app';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('token');
      userName = prefs.getString('user_name') ?? '';
      userEmail = prefs.getString('user_email') ?? '';
      userPhone = prefs.getString('user_phone') ?? '';
      userTaxiId = prefs.getString('taxi_id') ?? '';
      userMatricule = prefs.getString('user_matricule') ?? '';
      userRole = prefs.getString('user_role') ?? 'driver';
      userId = prefs.getInt('user_id');
      _isDarkMode = prefs.getString('app_theme') == 'dark';
      _selectedLanguage = prefs.getString('app_language') ?? 'English';

      if (authToken != null) {
        await _fetchProfileFromBackend();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchProfileFromBackend() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/profile'),
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final user = data['user'];
          final prefs = await SharedPreferences.getInstance();
          if (user['username'] != null &&
              user['username'].toString().isNotEmpty) {
            userName = user['username'];
            await prefs.setString('user_name', userName);
          }
          if (user['email'] != null && user['email'].toString().isNotEmpty) {
            userEmail = user['email'];
            await prefs.setString('user_email', userEmail);
          }
          if (user['phone'] != null && user['phone'].toString().isNotEmpty) {
            userPhone = user['phone'];
            await prefs.setString('user_phone', userPhone);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _saveThemeToBackend(String theme) async {
    if (authToken == null) return;
    try {
      await http.put(
        Uri.parse('$baseUrl/api/auth/settings'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'settings': {'app_theme': theme}
        }),
      );
    } catch (e) {
      debugPrint('Error saving theme to backend: $e');
    }
  }

  Future<void> _saveLanguageToBackend(String language) async {
    if (authToken == null) return;
    try {
      await http.put(
        Uri.parse('$baseUrl/api/auth/settings'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'settings': {'app_language': language}
        }),
      );
    } catch (e) {
      debugPrint('Error saving language to backend: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : Colors.grey[100],
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.yellow),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.grey[100],
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileCard(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _settingsTile(
                      icon: Icons.person,
                      title: "Edit Profile",
                      subtitle: "Update your personal information",
                      onTap: () => _showEditProfileDialog()),
                  const SizedBox(height: 12),
                  _settingsTile(
                      icon: Icons.lock,
                      title: "Change Password",
                      subtitle: "Update your security password",
                      onTap: () => _showChangePasswordDialog()),
                  const SizedBox(height: 12),
                  _settingsTile(
                    icon: Icons.color_lens,
                    title: "Theme",
                    subtitle: _isDarkMode
                        ? "Dark Mode (Current)"
                        : "Light Mode (Current)",
                    trailing: Switch(
                      value: _isDarkMode,
                      activeThumbColor: Colors.yellow,
                      activeTrackColor: Colors.yellow.withOpacity(0.5),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.withOpacity(0.3),
                      onChanged: (value) {
                        setState(() => _isDarkMode = value);
                        final themeStr = value ? 'dark' : 'light';
                        SharedPreferences.getInstance()
                            .then((p) => p.setString('app_theme', themeStr));
                        MyApp.of(context)?.setTheme(themeStr);
                        _saveThemeToBackend(themeStr);
                        _showThemeChangedSnackBar(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _settingsTile(
                      icon: Icons.language,
                      title: "Language",
                      subtitle: _selectedLanguage,
                      onTap: () => _showLanguageDialog()),
                  const SizedBox(height: 12),
                  _settingsTile(
                      icon: Icons.security,
                      title: "Privacy & Security",
                      subtitle: "Manage your privacy settings",
                      onTap: () => _showPrivacyDialog()),
                  const SizedBox(height: 12),
                  _settingsTile(
                      icon: Icons.info,
                      title: "App Version",
                      subtitle: "v1.0.0",
                      onTap: () {}),
                  const SizedBox(height: 12),
                  _settingsTile(
                      icon: Icons.logout,
                      title: "Logout",
                      subtitle: "Sign out from your account",
                      isDestructive: true,
                      onTap: () => _showLogoutDialog()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isDarkMode ? Colors.black : Colors.white,
      elevation: 0,
      title: Text("Settings & Profile",
          style: TextStyle(
              color: _isDarkMode ? Colors.yellow : Colors.black,
              fontWeight: FontWeight.bold)),
      iconTheme:
          IconThemeData(color: _isDarkMode ? Colors.yellow : Colors.black),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.yellow, width: 2)),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.yellow,
                backgroundImage:
                    _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null
                    ? Text(
                        userName.isNotEmpty
                            ? userName.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      )
                    : null,
              ),
              GestureDetector(
                onTap: _showImageSourceActionSheet,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(5),
                  child: const Icon(Icons.camera_alt,
                      size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(userName.isNotEmpty ? userName : 'Not set',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.yellow : Colors.black)),
          const SizedBox(height: 8),
          Text(
              "Taxi ID: ${userTaxiId.isNotEmpty ? userTaxiId : 'Not assigned'}",
              style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white70 : Colors.grey)),
          const SizedBox(height: 4),
          Text(userEmail.isNotEmpty ? userEmail : 'No email',
              style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? Colors.white70 : Colors.grey)),
          const SizedBox(height: 8),
          Text(
              "Matricule: ${userMatricule.isNotEmpty ? userMatricule : 'Not set'}",
              style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white70 : Colors.grey)),
          const SizedBox(height: 4),
          Text("Phone: ${userPhone.isNotEmpty ? userPhone : 'Not set'}",
              style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white70 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _settingsTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
      Widget? trailing,
      bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.5)
                : Colors.yellow.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDestructive ? Colors.red : Colors.yellow, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDestructive
                              ? Colors.red
                              : (_isDarkMode ? Colors.white : Colors.black))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: _isDarkMode ? Colors.white70 : Colors.grey)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    String newName = userName;
    String newEmail = userEmail;
    String newPhone = userPhone;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text("Edit Profile",
            style: TextStyle(
                color: _isDarkMode ? Colors.yellow : Colors.black,
                fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField("Full Name", newName, (v) => newName = v),
              const SizedBox(height: 16),
              _dialogTextField("Email", newEmail, (v) => newEmail = v),
              const SizedBox(height: 16),
              _dialogTextField("Phone Number", newPhone, (v) => newPhone = v),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
            onPressed: () async {
              if (authToken != null) {
                try {
                  final response = await http.put(
                    Uri.parse('$baseUrl/api/auth/profile'),
                    headers: {
                      'Authorization': 'Bearer $authToken',
                      'Content-Type': 'application/json'
                    },
                    body: jsonEncode({'username': newName, 'phone': newPhone}),
                  );
                  if (response.statusCode == 200) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_name', newName);
                    await prefs.setString('user_email', newEmail);
                    await prefs.setString('user_phone', newPhone);
                    setState(() {
                      userName = newName;
                      userEmail = newEmail;
                      userPhone = newPhone;
                    });
                    Navigator.pop(ctx);
                    _showSnackBar("Profile updated successfully!",
                        color: Colors.green);
                    return;
                  } else {
                    _showSnackBar("Failed to update profile on server");
                  }
                } catch (e) {
                  // Fallback to local save
                }
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_name', newName);
              await prefs.setString('user_email', newEmail);
              await prefs.setString('user_phone', newPhone);
              setState(() {
                userName = newName;
                userEmail = newEmail;
                userPhone = newPhone;
              });
              Navigator.pop(ctx);
              _showSnackBar("Profile saved locally", color: Colors.green);
            },
            child: const Text("Save",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogTextField(
      String label, String initial, ValueChanged<String> onChanged) {
    return TextField(
      controller: TextEditingController(text: initial),
      onChanged: onChanged,
      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: _isDarkMode ? Colors.yellow : Colors.black),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.yellow, width: 2)),
      ),
    );
  }

  void _showChangePasswordDialog() {
    String newPassword = "";
    String confirmPassword = "";
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text("Change Password",
              style: TextStyle(
                  color: _isDarkMode ? Colors.yellow : Colors.black,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  obscureText: !showPassword,
                  onChanged: (v) => newPassword = v,
                  style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: "New Password",
                    labelStyle: TextStyle(
                        color: _isDarkMode ? Colors.yellow : Colors.black),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Colors.yellow, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: !showPassword,
                  onChanged: (v) => confirmPassword = v,
                  style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    labelStyle: TextStyle(
                        color: _isDarkMode ? Colors.yellow : Colors.black),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Colors.yellow, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                        value: showPassword,
                        activeColor: Colors.yellow,
                        onChanged: (v) =>
                            setDialogState(() => showPassword = v ?? false)),
                    Text("Show Password",
                        style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              onPressed: () async {
                if (newPassword != confirmPassword) {
                  _showSnackBar("Passwords do not match!");
                  return;
                }
                if (newPassword.length < 6) {
                  _showSnackBar("Password must be at least 6 characters!");
                  return;
                }
                Navigator.pop(ctx);
                _showSnackBar("Password change requested", color: Colors.green);
              },
              child: const Text("Update Password",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
          source: source, imageQuality: 80, maxWidth: 900, maxHeight: 900);
      if (pickedFile != null) {
        setState(() => _profileImage = File(pickedFile.path));
        await _uploadProfileImage(pickedFile);
        _showSnackBar("Profile picture updated successfully!",
            color: Colors.green);
      }
    } catch (e) {
      _showSnackBar("Failed to pick image: $e");
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                }),
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                }),
            ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text("Privacy & Security",
            style: TextStyle(
                color: _isDarkMode ? Colors.yellow : Colors.black,
                fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _privacyOption(
                  title: "Location Sharing",
                  subtitle: "Allow location tracking for safety",
                  enabled: true),
              const SizedBox(height: 16),
              _privacyOption(
                  title: "Notifications",
                  subtitle: "Receive emergency and order alerts",
                  enabled: true),
              const SizedBox(height: 16),
              _privacyOption(
                  title: "Data Collection",
                  subtitle: "Help improve the app with usage data",
                  enabled: false),
              const SizedBox(height: 16),
              _privacyOption(
                  title: "Two-Factor Authentication",
                  subtitle: "Extra security for your account",
                  enabled: false),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _privacyOption(
      {required String title,
      required String subtitle,
      required bool enabled}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? Colors.white70 : Colors.grey)),
            ],
          ),
        ),
        Switch(
            value: enabled, activeThumbColor: Colors.yellow, onChanged: (_) {}),
      ],
    );
  }

  void _showThemeChangedSnackBar(bool isDark) {
    _showSnackBar(isDark ? "Switched to Dark Mode" : "Switched to Light Mode",
        color: Colors.yellow.withOpacity(0.9));
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text("Logout",
            style: TextStyle(
                color: _isDarkMode ? Colors.yellow : Colors.black,
                fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to logout?",
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false);
            },
            child: const Text("Logout",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    List<String> languages = ["English", "French", "Spanish", "German"];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text("Select Language",
            style: TextStyle(
                color: _isDarkMode ? Colors.yellow : Colors.black,
                fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              return RadioListTile<String>(
                title: Text(lang,
                    style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black)),
                value: lang,
                groupValue: _selectedLanguage,
                activeColor: Colors.yellow,
                onChanged: (value) {
                  setState(() => _selectedLanguage = value!);
                  final prefs = SharedPreferences.getInstance();
                  prefs.then((p) => p.setString('app_language', value!));
                  MyApp.of(context)?.setLanguage(value!);
                  _saveLanguageToBackend(value!);
                  Navigator.pop(ctx);
                  _showSnackBar("Language changed to $value",
                      color: Colors.green);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))
        ],
      ),
    );
  }

  Future<void> _uploadProfileImage(XFile imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        return;
      }
      final request =
          http.MultipartRequest('PUT', Uri.parse('$baseUrl/api/auth/profile'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
          await http.MultipartFile.fromPath('profileImage', imageFile.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        debugPrint('Profile image uploaded successfully');
      } else {
        _showSnackBar("Failed to upload image to server");
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
    }
  }
}

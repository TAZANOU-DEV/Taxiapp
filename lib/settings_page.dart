import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = true;
  String userName = "John Doe";
  String userEmail = "john@taxiapp.com";
  String userPhone = "+237 6 XX XX XX XX";
  String userTaxiId = "CM-TX-4589";
  String _selectedLanguage = "English";

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          "Settings & Profile",
          style: TextStyle(
            color: _isDarkMode ? Colors.yellow : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: _isDarkMode ? Colors.yellow : Colors.black,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Card Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.yellow,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.yellow,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? Text(
                                userName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              )
                            : null,
                      ),
                      GestureDetector(
                        onTap: _showImageSourceActionSheet,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(5),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.yellow : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Taxi ID: $userTaxiId",
                    style: TextStyle(
                      fontSize: 14,
                      color: _isDarkMode ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Vehicle: Toyota Camry - ABC 123",
                    style: TextStyle(
                      fontSize: 14,
                      color: _isDarkMode ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "License: TX-456789",
                    style: TextStyle(
                      fontSize: 14,
                      color: _isDarkMode ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Settings List
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Edit Profile
                  _settingsTile(
                    icon: Icons.person,
                    title: "Edit Profile",
                    subtitle: "Update your personal information",
                    onTap: () => _showEditProfileDialog(),
                  ),
                  const SizedBox(height: 12),
                  // Change Password
                  _settingsTile(
                    icon: Icons.lock,
                    title: "Change Password",
                    subtitle: "Update your security password",
                    onTap: () => _showChangePasswordDialog(),
                  ),
                  const SizedBox(height: 12),
                  // Theme Settings
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
                        setState(() {
                          _isDarkMode = value;
                        });
                        _showThemeChangedSnackBar(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Language Settings
                  _settingsTile(
                    icon: Icons.language,
                    title: "Language",
                    subtitle: _selectedLanguage,
                    onTap: () => _showLanguageDialog(),
                  ),
                  const SizedBox(height: 12),
                  // Privacy & Security
                  _settingsTile(
                    icon: Icons.security,
                    title: "Privacy & Security",
                    subtitle: "Manage your privacy settings",
                    onTap: () => _showPrivacyDialog(),
                  ),
                  const SizedBox(height: 12),
                  // App Version
                  _settingsTile(
                    icon: Icons.info,
                    title: "App Version",
                    subtitle: "v1.0.0",
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  // Logout
                  _settingsTile(
                    icon: Icons.logout,
                    title: "Logout",
                    subtitle: "Sign out from your account",
                    isDestructive: true,
                    onTap: () => _showLogoutDialog(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
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
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.yellow,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDestructive
                          ? Colors.red
                          : (_isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? Colors.white70 : Colors.grey,
                    ),
                  ),
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
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          "Edit Profile",
          style: TextStyle(
            color: _isDarkMode ? Colors.yellow : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: newName),
                onChanged: (value) => newName = value,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: "Full Name",
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.yellow : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.yellow, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: newEmail),
                onChanged: (value) => newEmail = value,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.yellow : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.yellow, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: newPhone),
                onChanged: (value) => newPhone = value,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.yellow : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.yellow, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
            ),
            onPressed: () {
              setState(() {
                userName = newName;
                userEmail = newEmail;
                userPhone = newPhone;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Profile updated successfully!"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              "Save",
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    String newPassword = "";
    String confirmPassword = "";
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            "Change Password",
            style: TextStyle(
              color: _isDarkMode ? Colors.yellow : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  obscureText: !showPassword,
                  onChanged: (value) => newPassword = value,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: "New Password",
                    labelStyle: TextStyle(
                      color: _isDarkMode ? Colors.yellow : Colors.black,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.yellow, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: !showPassword,
                  onChanged: (value) => confirmPassword = value,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    labelStyle: TextStyle(
                      color: _isDarkMode ? Colors.yellow : Colors.black,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.yellow, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: showPassword,
                      activeColor: Colors.yellow,
                      onChanged: (value) {
                        setDialogState(() {
                          showPassword = value ?? false;
                        });
                      },
                    ),
                    Text(
                      "Show Password",
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
              ),
              onPressed: () {
                if (newPassword != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Passwords do not match!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (newPassword.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password must be at least 6 characters!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password changed successfully!"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text(
                "Update Password",
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 900,
        maxHeight: 900,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile picture updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to pick image: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          "Privacy & Security",
          style: TextStyle(
            color: _isDarkMode ? Colors.yellow : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _privacyOption(
                title: "Location Sharing",
                subtitle: "Allow location tracking for safety",
                enabled: true,
              ),
              const SizedBox(height: 16),
              _privacyOption(
                title: "Notifications",
                subtitle: "Receive emergency and order alerts",
                enabled: true,
              ),
              const SizedBox(height: 16),
              _privacyOption(
                title: "Data Collection",
                subtitle: "Help improve the app with usage data",
                enabled: false,
              ),
              const SizedBox(height: 16),
              _privacyOption(
                title: "Two-Factor Authentication",
                subtitle: "Extra security for your account",
                enabled: false,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyOption({
    required String title,
    required String subtitle,
    required bool enabled,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          activeThumbColor: Colors.yellow,
          onChanged: (value) {},
        ),
      ],
    );
  }

  void _showThemeChangedSnackBar(bool isDark) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isDark ? "Switched to Dark Mode" : "Switched to Light Mode",
        ),
        backgroundColor: Colors.yellow.withOpacity(0.9),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          "Logout",
          style: TextStyle(
            color: _isDarkMode ? Colors.yellow : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to logout from your account?",
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text(
              "Logout",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    List<String> languages = ["English", "French", "Spanish", "German"];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          "Select Language",
          style: TextStyle(
            color: _isDarkMode ? Colors.yellow : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              return RadioListTile<String>(
                title: Text(
                  lang,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                value: lang,
                groupValue: _selectedLanguage,
                activeColor: Colors.yellow,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Language changed to $value"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }
}

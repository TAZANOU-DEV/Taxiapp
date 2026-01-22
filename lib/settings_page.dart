import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Settings"),
      ),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.person), title: Text("Edit Profile")),
          ListTile(leading: Icon(Icons.lock), title: Text("Change Password")),
          ListTile(
            leading: Icon(Icons.security),
            title: Text("Privacy & Security"),
          ),
          ListTile(leading: Icon(Icons.color_lens), title: Text("Theme")),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Logout"),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow.shade100,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("About Taxi App"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image / banner
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: AssetImage("assets/images/taxi_banner.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // App Introduction
            const Text(
              "Welcome to Taxi App",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Taxi App is designed to make your driving experience safer and more connected. "
              "You can share your location, send emergency alerts, and interact with nearby taximen instantly. "
              "Our goal is to ensure you always feel secure while on the road.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Features section
            const Text(
              "Features",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _featureTile(
              Icons.location_on,
              "Real-time Location Sharing",
              "Share your current location with nearby taximen to get instant support.",
            ),
            _featureTile(
              Icons.warning,
              "Emergency Alerts",
              "Send emergency notifications to nearby drivers with just one tap.",
            ),
            _featureTile(
              Icons.group,
              "Connect with Drivers",
              "Find and connect with other drivers nearby for collaboration.",
            ),
            _featureTile(
              Icons.history,
              "Activity Log",
              "Keep track of your trips, alerts, and other activities in one place.",
            ),
            const SizedBox(height: 20),

            // Call-to-action
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  // Example action: show a dialog
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Thank You!"),
                      content: const Text(
                        "We hope you enjoy using Taxi App. Drive safe!",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.emoji_emotions),
                label: const Text("Learn More", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Feature Tile Widget
  Widget _featureTile(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

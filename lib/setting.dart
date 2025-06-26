import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 8,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: ListView(
          children: [
            _buildSettingsTile(
              context: context,
              title: 'Account Settings',
              icon: Icons.person,
              onTap: () {
                // Add navigation or functionality for account settings
              },
            ),
            _buildSettingsTile(
              context: context,
              title: 'Notifications',
              icon: Icons.notifications,
              onTap: () {
                // Add navigation or functionality for notifications
              },
            ),
            _buildSettingsTile(
              context: context,
              title: 'Privacy',
              icon: Icons.lock,
              onTap: () {
                // Add navigation or functionality for privacy settings
              },
            ),
            _buildSettingsTile(
              context: context,
              title: 'Language',
              icon: Icons.language,
              onTap: () {
                // Add navigation or functionality for language settings
              },
            ),
            _buildSettingsTile(
              context: context,
              title: 'Help & Support',
              icon: Icons.help,
              onTap: () {
                // Add navigation or functionality for help
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.green.shade600, size: 30),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }
}
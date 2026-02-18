import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme_provider.dart';

class Contact {
  final String name;
  Contact({required this.name});
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = 'You';
  final String _whisprNo = '+1-9876-543-210';
  bool _enableNotifications = true;
  bool _enableMessagePreview = true;
  bool _enableSound = true;
  final String _storageInfo = 'Used: 2.5 MB / Total: Available';
  final List<String> _contactsList = ['Alice', 'Bob', 'Carmen', 'Daniel'];
  final List<String> _groupsList = ['Squad', 'Work Team'];

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF00C4E6),
      ),
      body: ListView(
        children: [
          // Profile Section
          _buildSectionHeader('Profile'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Edit Profile',
            subtitle: _userName,
            onTap: () => _showProfileEditor(context),
          ),
          _buildSettingsTile(
            icon: Icons.image,
            title: 'Change Profile Picture',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile picture picker - coming soon')),
              );
            },
          ),

          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            icon: Icons.phone,
            title: 'Whisprr Number',
            subtitle: _whisprNo,
            enabled: false,
          ),

          // Lists Section
          _buildSectionHeader('Lists'),
          _buildSettingsTile(
            icon: Icons.contacts,
            title: 'Manage Contacts',
            subtitle: '${_contactsList.length} contacts',
            onTap: () => _showContactsList(context),
          ),
          _buildSettingsTile(
            icon: Icons.groups,
            title: 'Manage Groups',
            subtitle: '${_groupsList.length} groups',
            onTap: () => _showGroupsList(context),
          ),

          // Chats Section
          _buildSectionHeader('Chats'),
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                context.read<ThemeProvider>().setDarkMode(value);
              },
              activeThumbColor: const Color(0xFF00C4E6),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.text_fields,
            title: 'Font Size',
            subtitle: 'Normal',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Font size customization - coming soon')),
              );
            },
          ),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSettingsTile(
            icon: Icons.notifications_active,
            title: 'Enable Notifications',
            trailing: Switch(
              value: _enableNotifications,
              onChanged: (value) {
                setState(() => _enableNotifications = value);
              },
              activeThumbColor: const Color(0xFF00C4E6),
            ),
          ),
          if (_enableNotifications)
            _buildSettingsTile(
              icon: Icons.message,
              title: 'Message Preview',
              trailing: Switch(
                value: _enableMessagePreview,
                onChanged: (value) {
                  setState(() => _enableMessagePreview = value);
                },
                activeThumbColor: const Color(0xFF00C4E6),
              ),
            ),
          if (_enableNotifications)
            _buildSettingsTile(
              icon: Icons.volume_up,
              title: 'Notification Sound',
              trailing: Switch(
                value: _enableSound,
                onChanged: (value) {
                  setState(() => _enableSound = value);
                },
                activeThumbColor: const Color(0xFF00C4E6),
              ),
            ),

          // Storage Section
          _buildSectionHeader('Storage and Data'),
          _buildSettingsTile(
            icon: Icons.storage,
            title: 'Storage Info',
            subtitle: _storageInfo,
          ),
          _buildSettingsTile(
            icon: Icons.delete,
            title: 'Clear Cache',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
          ),

          // Help Section
          _buildSectionHeader('Help & Feedback'),
          _buildSettingsTile(
            icon: Icons.help,
            title: 'FAQs',
            onTap: () => _showFAQs(context),
          ),
          _buildSettingsTile(
            icon: Icons.feedback,
            title: 'Send Feedback',
            onTap: () => _showFeedbackDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF00C4E6),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: enabled ? const Color(0xFF00C4E6) : Colors.grey),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: enabled ? onTap : null,
      enabled: enabled,
    );
  }

  void _showProfileEditor(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Enter your name'),
              controller: TextEditingController(text: _userName),
              onChanged: (value) => _userName = value,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C4E6)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showContactsList(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Contacts'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            itemCount: _contactsList.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(_contactsList[index]),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => _contactsList.removeAt(index));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact deleted')),
                  );
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showGroupsList(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Groups'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            itemCount: _groupsList.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(_groupsList[index]),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => _groupsList.removeAt(index));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted')),
                  );
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showFAQs(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FAQs'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(height: 10),
              Text('Q: How do I send a voice message?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text('A: Long-press the send button to start recording. Release to send.'),
              SizedBox(height: 15),
              Text('Q: How do I create a group?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text('A: Use the + button from home screen and select "Create Group".'),
              SizedBox(height: 15),
              Text('Q: How do I enable dark mode?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text('A: Go to Settings > Chats > Dark Mode and toggle it on.'),
              SizedBox(height: 15),
              Text('Q: How do I manage notifications?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text('A: Go to Settings > Notifications and customize your preferences.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We\'d love to hear from you!'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              decoration: InputDecoration(
                hintText: 'Type your feedback here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (feedbackController.text.isNotEmpty) {
                // Send feedback via email
                final emailUri = Uri(
                  scheme: 'mailto',
                  path: 'saahith3521@gmail.com',
                  queryParameters: {
                    'subject': 'Whisprr Feedback',
                    'body': feedbackController.text,
                  },
                );
                
                try {
                  await launchUrl(emailUri);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feedback sent successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error sending feedback. Please try again.')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C4E6)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

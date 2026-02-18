import 'package:flutter/material.dart';
import 'contact_selection.dart';
import 'chat_page.dart';
import 'settings_page.dart';
import 'group_creation.dart';
import 'qr_code_dialog.dart';

class Contact {
  final String name;
  final String lastMessage;
  final String time;

  Contact({required this.name, this.lastMessage = 'Hey there!', this.time = 'Now'});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Contact> _contacts = [
    Contact(name: 'Alice', lastMessage: 'See you soon', time: '9:12 AM'),
    Contact(name: 'Bob', lastMessage: 'Got it, thanks!', time: 'Yesterday'),
    Contact(name: 'Carmen', lastMessage: 'Let\'s catch up', time: 'Mon'),
    Contact(name: 'Daniel', lastMessage: '👍', time: 'Sun'),
  ];

  final List<Contact> _available = [
    Contact(name: 'Eve'),
    Contact(name: 'Frank'),
    Contact(name: 'Grace'),
    Contact(name: 'Hannah'),
  ];

  final List<Group> _groups = [];
  String _search = '';

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_add, color: Color(0xFF00C4E6)),
              title: const Text('Add Contact'),
              onTap: () {
                Navigator.pop(context);
                _addContact();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: Color(0xFF00C4E6)),
              title: const Text('Create Group'),
              onTap: () {
                Navigator.pop(context);
                _createGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addContact() async {
    final result = await Navigator.push<List<Contact>>(
      context,
      MaterialPageRoute(builder: (_) => ContactSelectionScreen(existing: _contacts, available: _available)),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        for (final c in result) {
          if (!_contacts.any((e) => e.name == c.name)) _contacts.insert(0, c);
        }
      });
    }
  }

  Future<void> _createGroup() async {
    final result = await Navigator.push<Group>(
      context,
      MaterialPageRoute(builder: (_) => GroupCreationPage(availableContacts: _available)),
    );
    if (result != null && mounted) {
      setState(() {
        _groups.add(result);
        // Add group to contacts list as well
        _contacts.insert(0, Contact(name: '👥 ${result.name}', lastMessage: '${result.members.length} members', time: 'Now'));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group "${result.name}" created with ${result.members.length} members')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔧 HomeScreen build');
    final filtered = _contacts.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4E6),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.message, color: Color(0xFF00C4E6), size: 20),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Whisprr', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: Colors.white),
            tooltip: 'QR Code & Device ID',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const QRCodeDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 320,
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black12))),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search or start new chat',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(contact.name[0])),
                        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(contact.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(contact.time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        onTap: () async {
                          // Open chat page
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(contact: contact)));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 96, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Select a chat to start messaging', style: TextStyle(fontSize: 18, color: Colors.black54)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        backgroundColor: const Color(0xFF00C4E6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
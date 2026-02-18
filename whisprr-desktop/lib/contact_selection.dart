import 'package:flutter/material.dart';
import 'home_screen.dart';

class ContactSelectionScreen extends StatefulWidget {
  final List<Contact> existing;
  final List<Contact> available;

  const ContactSelectionScreen({super.key, required this.existing, required this.available});

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  final Set<String> _selected = {};

  List<Contact> get _options => widget.available.where((c) => !widget.existing.any((e) => e.name == c.name)).toList();

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select contacts'),
        backgroundColor: const Color(0xFF00C4E6),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () {
                    final selectedContacts = options.where((c) => _selected.contains(c.name)).toList();
                    Navigator.pop(context, selectedContacts);
                  },
            child: Text('ADD', style: TextStyle(color: _selected.isEmpty ? Colors.white54 : Colors.white)),
          ),
        ],
      ),
        body: options.isEmpty
          ? Center(child: Text('No more contacts available', style: TextStyle(color: Colors.grey.shade600)))
          : ListView.separated(
            itemCount: options.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
                final c = options[index];
                final selected = _selected.contains(c.name);
                return ListTile(
                  leading: CircleAvatar(child: Text(c.name[0])),
                  title: Text(c.name),
                  trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF00C4E6)) : const Icon(Icons.radio_button_unchecked),
                  onTap: () => setState(() => selected ? _selected.remove(c.name) : _selected.add(c.name)),
                );
              },
            ),
    );
  }
}

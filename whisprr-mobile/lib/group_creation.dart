import 'package:flutter/material.dart';
import 'home_screen.dart';

class Group {
  final String name;
  final List<Contact> members;

  Group({required this.name, required this.members});
}

class GroupCreationPage extends StatefulWidget {
  final List<Contact> availableContacts;

  const GroupCreationPage({super.key, required this.availableContacts});

  @override
  State<GroupCreationPage> createState() => _GroupCreationPageState();
}

class _GroupCreationPageState extends State<GroupCreationPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final Set<String> _selectedMembers = {};

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: const Color(0xFF00C4E6),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Group Name Input
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  hintText: 'Enter group name',
                  labelText: 'Group Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.groups),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Members (${_selectedMembers.length} selected)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF00C4E6)),
                ),
              ),
            ),

            // Members List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.availableContacts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = widget.availableContacts[index];
                final isSelected = _selectedMembers.contains(contact.name);
                return ListTile(
                  leading: CircleAvatar(child: Text(contact.name[0])),
                  title: Text(contact.name),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedMembers.add(contact.name);
                        } else {
                          _selectedMembers.remove(contact.name);
                        }
                      });
                    },
                    activeColor: const Color(0xFF00C4E6),
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMembers.remove(contact.name);
                      } else {
                        _selectedMembers.add(contact.name);
                      }
                    });
                  },
                );
              },
            ),

            // Create Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _groupNameController.text.isEmpty || _selectedMembers.isEmpty
                      ? null
                      : () {
                          final selectedContacts = widget.availableContacts
                              .where((c) => _selectedMembers.contains(c.name))
                              .toList();
                          final newGroup = Group(
                            name: _groupNameController.text,
                            members: selectedContacts,
                          );
                          Navigator.pop(context, newGroup);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C4E6),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Create Group', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

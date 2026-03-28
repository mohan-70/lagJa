import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  void _updateDisplayName() {
    final controller = TextEditingController(text: _authService.currentUserName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Update Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: Color(0xFF8E8E93)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93)))),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
                  if (mounted) {
                    setState(() {});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              }
            },
            child: const Text('Update', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(String title, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Color(0xFF8E8E93))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93)))),
          TextButton(
            onPressed: () async {
              try {
                await action();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93)))),
          TextButton(
            onPressed: () async {
              try {
                await _authService.signOut();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete your account and all your data. This action is irreversible.', style: TextStyle(color: Color(0xFF8E8E93))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93)))),
          TextButton(
            onPressed: () async {
              try {
                await _firestoreService.deleteUserData();
                await FirebaseAuth.instance.currentUser?.delete();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSection(),
          const SizedBox(height: 24),
          _buildHeader("APP"),
          _buildGroup([
            _buildTile("App Version", trailing: "1.0.0"),
            _buildDivider(),
            _buildTile("Theme", trailing: "Dark"),
          ]),
          const SizedBox(height: 24),
          _buildHeader("DATA"),
          _buildGroup([
            _buildTile("Clear DSA Problems", showChevron: true, onTap: () => _confirmClearData("Clear DSA Problems?", _firestoreService.clearDSAProblems)),
            _buildDivider(),
            _buildTile("Clear Companies", showChevron: true, onTap: () => _confirmClearData("Clear Companies?", _firestoreService.clearCompanies)),
            _buildDivider(),
            _buildTile("Clear Notes", showChevron: true, onTap: () => _confirmClearData("Clear Notes?", _firestoreService.clearNotes)),
          ]),
          const SizedBox(height: 24),
          _buildHeader("ACCOUNT"),
          _buildGroup([
            _buildTile("Sign Out", isDestructive: true, onTap: _confirmSignOut),
            _buildDivider(),
            _buildTile("Delete Account", isDestructive: true, onTap: _confirmDeleteAccount),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final name = _authService.currentUserName ?? 'User';
    final email = _authService.currentUserEmail ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5)),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: const Color(0xFF6C63FF), child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    IconButton(onPressed: _updateDisplayName, icon: const Icon(Icons.edit_outlined, color: Color(0xFF8E8E93), size: 18)),
                  ],
                ),
                Text(email, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(text, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5)),
      child: Column(children: children),
    );
  }

  Widget _buildTile(String title, {String? trailing, bool showChevron = false, bool isDestructive = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      title: Text(title, style: TextStyle(color: isDestructive ? const Color(0xFFFF453A) : Colors.white, fontSize: 16)),
      trailing: trailing != null 
        ? Text(trailing, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 16))
        : showChevron ? const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)) : null,
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Color(0xFF2C2C2E), height: 0.5, indent: 16);
  }
}

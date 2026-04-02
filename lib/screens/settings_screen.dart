import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/ui_constants.dart';
import '../widgets/ui/section_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  void _updateDisplayName() {
    final controller =
        TextEditingController(text: _authService.currentUserName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.currentUser
                      ?.updateDisplayName(newName);
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name updated')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error));
                  }
                }
              }
            },
            child:
                const Text('Update', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(String title, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              try {
                await action();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data cleared')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              try {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error));
                }
              }
            },
            child:
                const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
            'This will permanently delete your account and all your data. This action is irreversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              try {
                await _firestoreService.deleteUserData();
                await FirebaseAuth.instance.currentUser?.delete();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error));
                }
              }
            },
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
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
          const SectionHeader("APP"),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildTile("App Version", trailing: "1.0.0"),
                _buildDivider(),
                _buildTile("Theme", trailing: "Unstop Light"),
                _buildDivider(),
                _buildTile(
                  "Privacy Policy",
                  trailingIcon: Icons.open_in_new,
                  onTap: () => launchUrl(
                      Uri.parse("https://mohan-70.github.io/lagja-privacy")),
                ),
              ],
            ),
          ),
          const SectionHeader("DATA MANAGEMENT"),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildTile("Clear DSA Problems",
                    showChevron: true,
                    onTap: () => _confirmClearData(
                        "Clear DSA Problems?", _firestoreService.clearDSAProblems)),
                _buildDivider(),
                _buildTile("Clear Companies",
                    showChevron: true,
                    onTap: () => _confirmClearData(
                        "Clear Companies?", _firestoreService.clearCompanies)),
                _buildDivider(),
                _buildTile("Clear Notes",
                    showChevron: true,
                    onTap: () => _confirmClearData(
                        "Clear Notes?", _firestoreService.clearNotes)),
              ],
            ),
          ),
          const SectionHeader("ACCOUNT"),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildTile("Sign Out", isDestructive: true, onTap: _confirmSignOut),
                _buildDivider(),
                _buildTile("Delete Account",
                    isDestructive: true, onTap: _confirmDeleteAccount),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final name = _authService.currentUserName ?? 'User';
    final email = _authService.currentUserEmail ?? '';
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.accent,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis)),
                      IconButton(
                          onPressed: _updateDisplayName,
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.textSecondary, size: 18)),
                    ],
                  ),
                  Text(email,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(String title,
      {String? trailing,
      IconData? trailingIcon,
      bool showChevron = false,
      bool isDestructive = false,
      VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title,
          style: TextStyle(
              color: isDestructive ? AppColors.error : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500)),
      trailing: trailingIcon != null
          ? Icon(trailingIcon, color: AppColors.textSecondary, size: 20)
          : (trailing != null
              ? Text(trailing,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 16))
              : (showChevron
                  ? const Icon(Icons.chevron_right, color: AppColors.textSecondary)
                  : null)),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: AppColors.border, height: 1, indent: 16);
  }
}

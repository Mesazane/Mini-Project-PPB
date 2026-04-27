// screens/widgets/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../utils/app_strings.dart';
import '../account_settings_screen.dart';
import '../settings_screen.dart';
import '../trash_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;
    final hasName = (user?.displayName?.trim().isNotEmpty ?? false);
    final name = hasName ? user!.displayName!.trim() : '-';
    final email = user?.email ?? '-';
    final initial =
        hasName ? name.characters.first.toUpperCase() : (email.isNotEmpty ? email.characters.first.toUpperCase() : '?');

    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ─── Header (custom, kontras tinggi) ───────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 24, 8, 20),
              color: primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: primary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // tombol logout di samping avatar
                      IconButton(
                        tooltip: AppStrings.of(context, 'logout'),
                        icon: Icon(Icons.logout, color: onPrimary),
                        onPressed: () async {
                          Navigator.pop(context);
                          await authService.logout();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasName ? name : email,
                    style: TextStyle(
                      color: onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasName)
                    Text(
                      email,
                      style: TextStyle(
                        color: onPrimary.withOpacity(0.85),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // ─── Menu items ────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(AppStrings.of(context, 'account_settings')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(AppStrings.of(context, 'trash')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrashScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppStrings.of(context, 'settings')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// screens/account_settings_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_strings.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? '-';
    final email = user?.email ?? '-';

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(context, 'account_settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(AppStrings.of(context, 'name')),
            subtitle: Text(name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangeNameDialog(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(AppStrings.of(context, 'email')),
            subtitle: Text(email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangeEmailDialog(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(AppStrings.of(context, 'change_password')),
            subtitle: const Text('••••••••'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(),
          ),
        ],
      ),
    );
  }

  // ─── Change name ─────────────────────────────────────────
  Future<void> _showChangeNameDialog() async {
    final controller = TextEditingController(
        text: FirebaseAuth.instance.currentUser?.displayName ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'change_name')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.of(ctx, 'new_name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.of(ctx, 'name_required')
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.of(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(AppStrings.of(ctx, 'save')),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final err = await _authService.updateName(result);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      } else {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context, 'updated')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ─── Change email ────────────────────────────────────────
  Future<void> _showChangeEmailDialog() async {
    final emailCtrl = TextEditingController();
    final pwCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(AppStrings.of(ctx, 'change_email')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppStrings.of(ctx, 'new_email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppStrings.of(ctx, 'email_required');
                    }
                    if (!v.contains('@')) {
                      return AppStrings.of(ctx, 'email_invalid');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pwCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: AppStrings.of(ctx, 'current_password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setLocal(() => obscure = !obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppStrings.of(ctx, 'password_required')
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.of(ctx, 'cancel')),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(AppStrings.of(ctx, 'save')),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final err = await _authService.updateEmail(
        newEmail: emailCtrl.text,
        currentPassword: pwCtrl.text,
      );
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context, 'email_verify_sent')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ─── Change password ─────────────────────────────────────
  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(AppStrings.of(ctx, 'change_password')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: AppStrings.of(ctx, 'current_password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppStrings.of(ctx, 'password_required')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: AppStrings.of(ctx, 'new_password'),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setLocal(() => obscure = !obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return AppStrings.of(ctx, 'password_required');
                    }
                    if (v.length < 6) {
                      return AppStrings.of(ctx, 'password_min');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: AppStrings.of(ctx, 'password_confirm'),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) => (v != newCtrl.text)
                      ? AppStrings.of(ctx, 'password_mismatch')
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.of(ctx, 'cancel')),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(AppStrings.of(ctx, 'save')),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final err = await _authService.updatePassword(
        currentPassword: currentCtrl.text,
        newPassword: newCtrl.text,
      );
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context, 'updated')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

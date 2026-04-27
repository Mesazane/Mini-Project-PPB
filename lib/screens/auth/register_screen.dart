// screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../utils/app_strings.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final error = await _authService.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      TextInput.finishAutofillContext();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun berhasil dibuat'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(context, 'register_account'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.person_add_alt_1,
                      size: 64, color: Color(0xFF1E88E5)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context, 'name'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return AppStrings.of(context, 'name_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context, 'email'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return AppStrings.of(context, 'email_required');
                      }
                      if (!val.contains('@')) {
                        return AppStrings.of(context, 'email_invalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '${AppStrings.of(context, 'password')} (min 6)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return AppStrings.of(context, 'password_required');
                      }
                      if (val.length < 6) {
                        return AppStrings.of(context, 'password_min');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context, 'password_confirm'),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (val) {
                      if (val != _passwordController.text) {
                        return AppStrings.of(context, 'password_mismatch');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppStrings.of(context, 'register')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

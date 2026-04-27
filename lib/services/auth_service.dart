// services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Terjadi kesalahan, coba lagi.';
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.reload();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Terjadi kesalahan, coba lagi.';
    }
  }

  Future<void> logout() async => _auth.signOut();

  // ── Profile updates ───────────────────────────────────────

  Future<String?> updateName(String newName) async {
    try {
      await _auth.currentUser?.updateDisplayName(newName.trim());
      await _auth.currentUser?.reload();
      return null;
    } catch (e) {
      return 'Gagal update nama: $e';
    }
  }

  /// Update email butuh re-auth dengan password lama.
  Future<String?> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User belum login';
      // re-auth
      final cred = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      // gunakan verifyBeforeUpdateEmail (Firebase modern)
      await user.verifyBeforeUpdateEmail(newEmail.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Gagal update email: $e';
    }
  }

  /// Update password butuh re-auth dengan password lama.
  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User belum login';
      final cred = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Gagal update password: $e';
    }
  }

  String displayLabel() {
    final user = _auth.currentUser;
    if (user == null) return '-';
    final name = user.displayName;
    if (name != null && name.trim().isNotEmpty) return name;
    return user.email ?? '-';
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password minimal 6 karakter.';
      case 'requires-recent-login':
        return 'Login ulang dulu sebelum mengubah email/password sensitif.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah.';
      default:
        return 'Gagal: $code';
    }
  }
}

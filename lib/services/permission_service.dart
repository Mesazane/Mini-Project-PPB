// services/permission_service.dart

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request akses media (foto + video) di awal aplikasi.
  /// Non-blocking: kalau user deny, app tetap bisa jalan dengan fitur terbatas.
  static Future<void> requestAtStartup() async {
    try {
      // Android 13+ pakai photos & videos terpisah, < 13 pakai storage.
      // permission_handler menangani API level mapping otomatis.
      await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
        Permission.notification,
      ].request();
    } catch (_) {
      // ignore — beberapa platform (web/desktop) tidak support
    }
  }
}

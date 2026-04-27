// services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service notifikasi lokal — tampilkan system notification saat upload sukses.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Inisialisasi plugin & channel. Aman dipanggil berkali-kali.
  static Future<void> init() async {
    if (_initialized) return;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // Android 13+: minta izin POST_NOTIFICATIONS
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    // Buat channel khusus untuk upload notifications
    const channel = AndroidNotificationChannel(
      'upload_channel',
      'Upload Notifications',
      description: 'Notifikasi saat dokumentasi berhasil di-upload',
      importance: Importance.high,
    );
    await androidImpl?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Tampilkan notifikasi sukses upload.
  static Future<void> showUploadSuccess({
    required String title,
    required String fileName,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'upload_channel',
      'Upload Notifications',
      channelDescription:
          'Notifikasi saat dokumentasi berhasil di-upload',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      ticker: 'DocumTracker',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Upload berhasil',
      'Dokumentasi "$title" ($fileName) tersimpan',
      details,
    );
  }

  /// Notifikasi generic — bisa dipakai untuk event lain.
  static Future<void> show({
    required String title,
    required String body,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'upload_channel',
      'Upload Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

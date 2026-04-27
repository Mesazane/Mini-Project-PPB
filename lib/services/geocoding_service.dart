// services/geocoding_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reverse geocoding pakai Nominatim (OpenStreetMap) — gratis tanpa API key.
/// Hasil di-cache memori supaya tidak hit endpoint berulang.
class GeocodingService {
  static final Map<String, String> _cache = {};
  static final Map<String, DateTime> _lastFetchAt = {};
  static DateTime _lastRequestTime = DateTime(2000);

  /// Bersihkan cache geocoding (dipanggil saat user tap Refresh).
  static void clearCache() {
    _cache.clear();
    _lastFetchAt.clear();
  }

  /// Parse string EXIF GPS ke decimal degrees.
  /// Format umum: "37 deg 25' 19.07\"" atau "[37, 25, 19.07]" atau
  /// "37/1, 25/1, 1907/100"
  static double? parseExifGps(String raw, String ref) {
    try {
      // ekstrak semua angka (mungkin pecahan x/y)
      final matches = RegExp(r'(-?\d+(?:\.\d+)?(?:/\d+)?)')
          .allMatches(raw)
          .map((m) => m.group(0)!)
          .toList();
      if (matches.length < 3) return null;

      double parseRational(String s) {
        if (s.contains('/')) {
          final parts = s.split('/');
          final num = double.parse(parts[0]);
          final den = double.parse(parts[1]);
          if (den == 0) return 0;
          return num / den;
        }
        return double.parse(s);
      }

      final deg = parseRational(matches[0]);
      final min = parseRational(matches[1]);
      final sec = parseRational(matches[2]);

      double decimal = deg + min / 60.0 + sec / 3600.0;

      final r = ref.trim().toUpperCase();
      if (r == 'S' || r == 'W') decimal = -decimal;
      return decimal;
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocode lat/lng → nama tempat. Return null kalau gagal/timeout.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    // round ke 3 desimal (~110m) untuk grouping & cache
    final key = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    if (_cache.containsKey(key)) return _cache[key];

    // rate limit: Nominatim minta 1 req/detik
    final since = DateTime.now().difference(_lastRequestTime);
    if (since < const Duration(milliseconds: 1100)) {
      await Future.delayed(const Duration(milliseconds: 1100) - since);
    }
    _lastRequestTime = DateTime.now();

    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': lat.toStringAsFixed(6),
        'lon': lng.toStringAsFixed(6),
        'zoom': '14', // suburb / district level
        'addressdetails': '1',
      });

      final resp = await http.get(url, headers: {
        'User-Agent': 'DocumTracker/1.0 (academic-project)',
        'Accept-Language': 'id,en',
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        String? name;
        if (addr != null) {
          name = (addr['suburb'] ??
                  addr['neighbourhood'] ??
                  addr['village'] ??
                  addr['town'] ??
                  addr['city'] ??
                  addr['county'] ??
                  addr['state'])
              ?.toString();
        }
        name ??= (data['display_name']?.toString().split(',').first);
        if (name != null && name.isNotEmpty) {
          _cache[key] = name;
          _lastFetchAt[key] = DateTime.now();
          return name;
        }
      }
    } catch (e) {
      // ignore — return null, caller akan tampilkan koordinat sebagai fallback
    }
    return null;
  }

  /// Bulat koordinat untuk grouping. Default 2 desimal (~1.1 km).
  static String roundedKey(double lat, double lng, {int precision = 2}) {
    return '${lat.toStringAsFixed(precision)},${lng.toStringAsFixed(precision)}';
  }
}

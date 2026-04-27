// services/file_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:native_exif/native_exif.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

class FileService {
  static const int maxBase64Length = 900000; // ~900 KB

  Future<String> encodeFile(File file) async {
    final bytes = await file.readAsBytes();
    final encoded = base64Encode(bytes);
    if (encoded.length > maxBase64Length) {
      final kb = (encoded.length / 1024).toStringAsFixed(0);
      throw Exception(
        'Ukuran file terlalu besar ($kb KB). '
        'Maksimal ~900 KB karena dibatasi Firestore. '
        'Untuk video, pilih video yang lebih pendek/kecil.',
      );
    }
    return encoded;
  }

  Uint8List decode(String base64Str) => base64Decode(base64Str);

  /// Tulis bytes ke temp file (dipakai untuk play video dari base64).
  Future<File> writeBytesToTemp(
    Uint8List bytes, {
    String fileName = 'temp.bin',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, fileName));
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile;
  }

  /// Simpan media ke galeri device. Jika sudah pernah didownload di sesi ini,
  /// tambahkan suffix (1), (2), dst.
  static final Map<String, int> _downloadCounts = {};

  Future<String> downloadToGallery({
    required String base64Str,
    required String mediaType, // 'image' atau 'video'
    required String fileName,
    Map<String, String> metadata = const {},
  }) async {
    final bytes = decode(base64Str);

    // Logic penomoran duplikat (1), (2), dst
    String finalName = fileName;
    if (_downloadCounts.containsKey(fileName)) {
      final count = _downloadCounts[fileName]!;
      final ext = p.extension(fileName);
      final base = p.basenameWithoutExtension(fileName);
      finalName = '$base ($count)$ext';
      _downloadCounts[fileName] = count + 1;
    } else {
      _downloadCounts[fileName] = 1;
    }

    SaveResult result;
    if (mediaType == 'image') {
      // Untuk image, tulis ke temp dulu untuk menyuntikkan EXIF
      final tempFile = await writeBytesToTemp(bytes, fileName: finalName);
      
      // EXIF (termasuk GPS) seharusnya sudah ke-preserve di JPEG bytes
      // dari proses kompresi `image` package saat upload. Injeksi tambahan
      // di sini hanya sebagai fallback untuk dokumen lama yang belum punya
      // EXIF di byte-nya. Setiap field di-try terpisah supaya 1 field error
      // tidak gagalkan seluruh batch.
      if (metadata.isNotEmpty) {
        try {
          final exif = await Exif.fromPath(tempFile.path);

          // Hanya field-field "aman" yang formatnya jelas string/numerik.
          // GPS sengaja dilewat karena formatnya rational array & sering
          // bikin native_exif throw.
          final safeMapping = {
            'dateTimeOriginal': 'DateTimeOriginal',
            'dateTimeDigitized': 'DateTimeDigitized',
            'dateTime': 'DateTime',
            'make': 'Make',
            'model': 'Model',
            'software': 'Software',
          };

          for (var entry in safeMapping.entries) {
            final value = metadata[entry.key];
            if (value == null || value.isEmpty) continue;
            try {
              await exif.writeAttributes({entry.value: value});
            } catch (e) {
              // skip field yang gagal, lanjut ke field berikutnya
              print('Skip EXIF ${entry.value}: $e');
            }
          }
          await exif.close();
        } catch (e) {
          print('Gagal akses EXIF temp file: $e');
        }
      }

      result = await SaverGallery.saveFile(
        filePath: tempFile.path,
        fileName: finalName,
        skipIfExists: false,
      );
      
      // Cleanup temp file setelah save (opsional, saver_gallery biasanya copy)
      tempFile.delete().catchError((_) => tempFile);
    } else {
      final tempFile = await writeBytesToTemp(bytes, fileName: finalName);
      result = await SaverGallery.saveFile(
        filePath: tempFile.path,
        fileName: finalName,
        skipIfExists: false,
      );
      tempFile.delete().catchError((_) => tempFile);
    }

    if (!result.isSuccess) {
      throw Exception(
          'Gagal simpan ke galeri: ${result.errorMessage ?? "unknown"}');
    }
    return finalName;
  }
}

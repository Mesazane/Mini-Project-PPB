// screens/document_detail_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../models/document_item.dart';
import '../services/document_service.dart';
import '../services/file_service.dart';
import '../utils/app_strings.dart';
import 'document_form_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final DocumentItem item;

  const DocumentDetailScreen({super.key, required this.item});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _fileService = FileService();
  final _docService = DocumentService();

  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  File? _tempVideoFile;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.mediaType == 'video' &&
        widget.item.mediaBase64.isNotEmpty) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final bytes = _fileService.decode(widget.item.mediaBase64);
      final tempFile = await _fileService.writeBytesToTemp(
        bytes,
        fileName: widget.item.fileName.isNotEmpty
            ? 'preview_${widget.item.fileName}'
            : 'preview.mp4',
      );
      _tempVideoFile = tempFile;
      _videoController = VideoPlayerController.file(tempFile)
        ..initialize().then((_) {
          if (mounted) setState(() => _isVideoReady = true);
        });
    } catch (e) {
      debugPrint('Error init video: $e');
    }
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final saved = await _fileService.downloadToGallery(
        base64Str: widget.item.mediaBase64,
        mediaType: widget.item.mediaType,
        fileName: widget.item.fileName,
        metadata: widget.item.metadata,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${AppStrings.of(context, 'downloaded_to_gallery')}: $saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Gagal download: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'delete_doc_title')),
        content: Text(
            '${AppStrings.of(ctx, 'delete_doc_msg')} "${widget.item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.of(ctx, 'delete')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _docService.deleteDocument(widget.item); // soft delete -> trash
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context, 'moved_to_trash')),
          action: SnackBarAction(
            label: AppStrings.of(context, 'restore'),
            onPressed: () => _docService.restore(widget.item.id),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _tempVideoFile?.delete().catchError((_) => _tempVideoFile!);
    super.dispose();
  }

  Widget _buildMedia() {
    if (widget.item.mediaBase64.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        height: 220,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
      );
    }

    if (widget.item.mediaType == 'video') {
      if (!_isVideoReady || _videoController == null) {
        return Container(
          color: Colors.black87,
          height: 220,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }
      return _VideoPlayerWithControls(controller: _videoController!);
    }

    return InteractiveViewer(
      child: Image.memory(
        _fileService.decode(widget.item.mediaBase64),
        fit: BoxFit.contain,
      ),
    );
  }

  // ─── Metadata helpers ─────────────────────────────────────

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String? _parseExifDate(String raw) {
    // EXIF format biasanya: '2026:04:25 12:31:28'
    try {
      final clean = raw.trim();
      final parts = clean.split(' ');
      if (parts.length != 2) return null;
      final date = parts[0].replaceAll(':', '-');
      return DateFormat('dd MMMM yyyy, HH:mm')
          .format(DateTime.parse('${date}T${parts[1]}'));
    } catch (_) {
      return raw;
    }
  }

  Widget _buildMetadataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    final meta = widget.item.metadata;
    final rows = <Widget>[];

    // Tanggal upload (selalu ada)
    rows.add(_buildMetadataRow(
      Icons.cloud_upload_outlined,
      AppStrings.of(context, 'date_uploaded'),
      DateFormat('dd MMMM yyyy, HH:mm').format(widget.item.createdAt),
    ));

    // Tanggal foto diambil (kalau ada)
    final dtOrig =
        meta['dateTimeOriginal'] ?? meta['dateTime'] ?? meta['dateTimeDigitized'];
    if (dtOrig != null && dtOrig.isNotEmpty) {
      rows.add(_buildMetadataRow(
        Icons.access_time,
        AppStrings.of(context, 'date_taken'),
        _parseExifDate(dtOrig) ?? dtOrig,
      ));
    }

    // Resolusi
    final w = meta['width'];
    final h = meta['height'];
    if (w != null && h != null) {
      rows.add(_buildMetadataRow(
        Icons.aspect_ratio,
        AppStrings.of(context, 'dimensions'),
        '$w × $h px',
      ));
    }

    // Ukuran
    final size = meta['fileSize'];
    if (size != null) {
      final n = int.tryParse(size);
      if (n != null) {
        rows.add(_buildMetadataRow(
          Icons.sd_storage_outlined,
          AppStrings.of(context, 'file_size'),
          _formatBytes(n),
        ));
      }
    }

    // Kamera
    final make = meta['make'];
    final model = meta['model'];
    if (make != null || model != null) {
      final camera =
          [make, model].where((e) => e != null && e.isNotEmpty).join(' ');
      if (camera.isNotEmpty) {
        rows.add(_buildMetadataRow(
          Icons.photo_camera_outlined,
          AppStrings.of(context, 'camera'),
          camera,
        ));
      }
    }

    if (meta['iso'] != null) {
      rows.add(_buildMetadataRow(
        Icons.iso,
        AppStrings.of(context, 'iso'),
        meta['iso']!,
      ));
    }
    if (meta['aperture'] != null) {
      rows.add(_buildMetadataRow(
        Icons.camera_outlined,
        AppStrings.of(context, 'aperture'),
        'f/${meta['aperture']}',
      ));
    }
    if (meta['exposureTime'] != null) {
      rows.add(_buildMetadataRow(
        Icons.shutter_speed,
        AppStrings.of(context, 'shutter'),
        '${meta['exposureTime']}s',
      ));
    }
    if (meta['focalLength'] != null) {
      rows.add(_buildMetadataRow(
        Icons.center_focus_strong_outlined,
        AppStrings.of(context, 'focal_length'),
        '${meta['focalLength']}mm',
      ));
    }
    if (meta['orientation'] != null) {
      rows.add(_buildMetadataRow(
        Icons.screen_rotation,
        AppStrings.of(context, 'orientation'),
        meta['orientation']!,
      ));
    }
    final lat = meta['gpsLat'];
    final lng = meta['gpsLng'];
    if (lat != null && lng != null) {
      rows.add(_buildMetadataRow(
        Icons.location_on_outlined,
        AppStrings.of(context, 'gps'),
        '${meta['gpsLatRef'] ?? ''} $lat, ${meta['gpsLngRef'] ?? ''} $lng',
      ));
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.of(context, 'metadata').toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context, 'detail')),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context, 'edit'),
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentFormScreen(existingItem: widget.item),
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.of(context, 'download'),
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            onPressed: _isDownloading ? null : _download,
          ),
          IconButton(
            tooltip: AppStrings.of(context, 'delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Colors.black,
              child: _buildMedia(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.item.mediaType == 'video'
                            ? Icons.videocam
                            : Icons.image,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.item.mediaType == 'video'
                            ? AppStrings.of(context, 'video')
                            : AppStrings.of(context, 'photo'),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.insert_drive_file,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.item.fileName.isEmpty
                              ? '-'
                              : widget.item.fileName,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.item.description.isEmpty)
                    Text(
                      AppStrings.of(context, 'no_description'),
                      style: const TextStyle(color: Colors.grey),
                    )
                  else
                    Text(
                      widget.item.description,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  _buildMetadataSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Video player + slider seek + tombol play/pause + waktu kanan-kiri.
class _VideoPlayerWithControls extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoPlayerWithControls({required this.controller});

  @override
  State<_VideoPlayerWithControls> createState() =>
      _VideoPlayerWithControlsState();
}

class _VideoPlayerWithControlsState extends State<_VideoPlayerWithControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final pos = c.value.position;
    final dur = c.value.duration;
    return Column(
      children: [
        AspectRatio(
          aspectRatio:
              c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              GestureDetector(
                onTap: () {
                  if (c.value.isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                  }
                },
                child: VideoPlayer(c),
              ),
              if (!c.value.isPlaying)
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    alignment: Alignment.center,
                    child: const Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 72),
                  ),
                ),
            ],
          ),
        ),
        // Slider + waktu
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (c.value.isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                  }
                },
              ),
              Text(_fmt(pos),
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Slider(
                    value: pos.inMilliseconds
                        .toDouble()
                        .clamp(0, dur.inMilliseconds.toDouble()),
                    max: dur.inMilliseconds == 0
                        ? 1
                        : dur.inMilliseconds.toDouble(),
                    onChanged: (v) {
                      c.seekTo(Duration(milliseconds: v.toInt()));
                    },
                  ),
                ),
              ),
              Text(_fmt(dur),
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

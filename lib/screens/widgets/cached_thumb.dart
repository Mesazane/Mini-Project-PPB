// screens/widgets/cached_thumb.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Widget thumbnail yang men-cache hasil decode base64 supaya tidak
/// re-decode setiap parent rebuild (mencegah flicker saat select).
class CachedThumb extends StatefulWidget {
  final String docId;
  final String base64Str;
  final BoxFit fit;

  const CachedThumb({
    super.key,
    required this.docId,
    required this.base64Str,
    this.fit = BoxFit.cover,
  });

  static final Map<String, Uint8List> _cache = {};

  static void invalidate(String docId) {
    _cache.remove(docId);
  }

  static Uint8List? cached(String docId) => _cache[docId];

  @override
  State<CachedThumb> createState() => _CachedThumbState();
}

class _CachedThumbState extends State<CachedThumb> {
  late Uint8List _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedThumb old) {
    super.didUpdateWidget(old);
    if (old.docId != widget.docId || old.base64Str != widget.base64Str) {
      CachedThumb._cache.remove(old.docId);
      _bytes = _resolve();
    }
  }

  Uint8List _resolve() {
    final cached = CachedThumb._cache[widget.docId];
    if (cached != null) return cached;
    final decoded = base64Decode(widget.base64Str);
    CachedThumb._cache[widget.docId] = decoded;
    return decoded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.base64Str.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
    return Image.memory(
      _bytes,
      fit: widget.fit,
      gaplessPlayback: true, // tidak hilang saat rebuild
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image),
      ),
    );
  }
}

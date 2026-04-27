// screens/trash_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/document_item.dart';
import '../models/folder_item.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/folder_service.dart';
import '../utils/app_strings.dart';
import 'widgets/cached_thumb.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _authService = AuthService();
  final _docService = DocumentService();
  final _folderService = FolderService();

  int _daysLeft(DateTime? deletedAt) {
    if (deletedAt == null) return 30;
    final expiry = deletedAt.add(const Duration(days: 30));
    final left = expiry.difference(DateTime.now()).inDays;
    return left.clamp(0, 30);
  }

  Future<void> _emptyTrashAll(List<DocumentItem> docs, List<FolderItem> folders) async {
    if (docs.isEmpty && folders.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'empty_trash')),
        content: Text(AppStrings.of(ctx, 'empty_trash_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.of(ctx, 'delete_forever')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // bersihkan thumbnail cache
      for (final d in docs) {
        CachedThumb.invalidate(d.id);
      }
      await _docService.permanentDeleteMany(docs.map((d) => d.id).toList());
      await _folderService
          .permanentDeleteMany(folders.map((f) => f.id).toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context, 'permanently_deleted'))),
      );
    }
  }

  Future<void> _restoreDoc(DocumentItem item) async {
    await _docService.restore(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context, 'restored'))),
    );
  }

  Future<void> _restoreFolder(FolderItem folder) async {
    await _folderService.restore(folder.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context, 'restored'))),
    );
  }

  Future<void> _permanentDeleteDoc(DocumentItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'delete_forever')),
        content: Text(AppStrings.of(ctx, 'delete_forever_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.of(ctx, 'delete_forever')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      CachedThumb.invalidate(item.id);
      await _docService.permanentDelete(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context, 'permanently_deleted'))),
      );
    }
  }

  Future<void> _permanentDeleteFolder(FolderItem folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'delete_forever')),
        content: Text(AppStrings.of(ctx, 'delete_forever_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.of(ctx, 'delete_forever')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _folderService.permanentDelete(folder.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context, 'permanently_deleted'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final userId = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context, 'trash')),
        actions: [
          StreamBuilder<List<DocumentItem>>(
            stream: _docService.streamTrashedDocuments(userId),
            builder: (ctx, dSnap) {
              return StreamBuilder<List<FolderItem>>(
                stream: _folderService.streamTrashedFolders(userId),
                builder: (ctx, fSnap) {
                  final docs = dSnap.data ?? [];
                  final folders = fSnap.data ?? [];
                  if (docs.isEmpty && folders.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: AppStrings.of(context, 'empty_trash'),
                    onPressed: () => _emptyTrashAll(docs, folders),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<FolderItem>>(
        stream: _folderService.streamTrashedFolders(userId),
        builder: (ctx, folderSnap) {
          final folders = folderSnap.data ?? [];
          return StreamBuilder<List<DocumentItem>>(
            stream: _docService.streamTrashedDocuments(userId),
            builder: (ctx, docSnap) {
              if (docSnap.connectionState == ConnectionState.waiting &&
                  !docSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = docSnap.data ?? [];
              docs.sort((a, b) => (b.deletedAt ?? b.createdAt)
                  .compareTo(a.deletedAt ?? a.createdAt));

              if (folders.isEmpty && docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context, 'trash_empty'),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // banner info
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppStrings.of(context, 'trash_hint'),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (folders.isNotEmpty) ...[
                    _sectionHeader(AppStrings.of(context, 'folders')),
                    ...folders.map((f) => _folderTile(f)),
                  ],
                  if (docs.isNotEmpty) ...[
                    _sectionHeader(AppStrings.of(context, 'files')),
                    ...docs.map((d) => _docTile(d)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _folderTile(FolderItem folder) {
    final daysLeft = _daysLeft(folder.deletedAt);
    return ListTile(
      leading: Icon(Icons.folder, color: folder.color, size: 36),
      title: Text(folder.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_countdownText(daysLeft, context),
          style: TextStyle(
              fontSize: 12,
              color: daysLeft <= 3 ? Colors.red : Colors.grey)),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'restore') _restoreFolder(folder);
          if (v == 'delete') _permanentDeleteFolder(folder);
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'restore',
            child: Row(children: [
              const Icon(Icons.restore, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(AppStrings.of(ctx, 'restore')),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_forever,
                  size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(AppStrings.of(ctx, 'delete_forever'),
                  style: const TextStyle(color: Colors.red)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _docTile(DocumentItem item) {
    final isVideo = item.mediaType == 'video';
    final daysLeft = _daysLeft(item.deletedAt);
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isVideo
              ? Container(
                  color: Colors.black87,
                  child: const Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 32),
                )
              : CachedThumb(
                  docId: item.id,
                  base64Str: item.mediaBase64,
                ),
        ),
      ),
      title: Text(item.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.fileName,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontFamily: 'monospace')),
          Text(_countdownText(daysLeft, context),
              style: TextStyle(
                  fontSize: 12,
                  color: daysLeft <= 3 ? Colors.red : Colors.grey)),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'restore') _restoreDoc(item);
          if (v == 'delete') _permanentDeleteDoc(item);
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'restore',
            child: Row(children: [
              const Icon(Icons.restore, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(AppStrings.of(ctx, 'restore')),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_forever,
                  size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(AppStrings.of(ctx, 'delete_forever'),
                  style: const TextStyle(color: Colors.red)),
            ]),
          ),
        ],
      ),
    );
  }

  String _countdownText(int daysLeft, BuildContext context) {
    if (daysLeft == 0) return AppStrings.of(context, 'expires_today');
    return '$daysLeft ${AppStrings.of(context, 'days_left')}';
  }
}

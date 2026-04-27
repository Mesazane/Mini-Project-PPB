// services/folder_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/folder_item.dart';

class FolderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('folders');

  /// Stream folder aktif (belum di-trash) di parent tertentu.
  Stream<List<FolderItem>> streamFolders(String userId, {String parentId = ''}) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => FolderItem.fromDoc(d))
          .where((f) => !f.isDeleted)
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Stream folder yang ada di trash.
  Stream<List<FolderItem>> streamTrashedFolders(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => FolderItem.fromDoc(d))
          .where((f) => f.isDeleted)
          .toList();
      list.sort((a, b) =>
          (b.deletedAt ?? b.createdAt).compareTo(a.deletedAt ?? a.createdAt));
      return list;
    });
  }

  Future<void> addFolder(FolderItem item) async {
    await _col.add(item.toMap());
  }

  Future<void> renameFolder(String id, String newName) async {
    await _col.doc(id).update({'name': newName});
  }

  Future<void> updateFolder(String id, String name, int colorValue) async {
    await _col.doc(id).update({
      'name': name,
      'colorValue': colorValue,
    });
  }

  Future<void> moveFolders(List<String> ids, String targetParentId) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_col.doc(id), {'parentId': targetParentId});
    }
    await batch.commit();
  }

  Future<void> updateColor(String id, int colorValue) async {
    await _col.doc(id).update({'colorValue': colorValue});
  }

  Future<void> updateColorMany(List<String> ids, int colorValue) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_col.doc(id), {'colorValue': colorValue});
    }
    await batch.commit();
  }

  // ── Soft delete / restore / permanent ────────────────────────
  Future<void> softDelete(String id) async {
    await _col.doc(id).update({'isDeleted': true, 'deletedAt': Timestamp.now()});
  }

  Future<void> softDeleteMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    final now = Timestamp.now();
    for (final id in ids) {
      batch.update(_col.doc(id), {'isDeleted': true, 'deletedAt': now});
    }
    await batch.commit();
  }

  Future<void> restore(String id) async {
    await _col.doc(id).update({'isDeleted': false, 'deletedAt': null});
  }

  Future<void> restoreMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_col.doc(id), {'isDeleted': false, 'deletedAt': null});
    }
    await batch.commit();
  }

  Future<void> permanentDelete(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> permanentDeleteMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
  }

  // ── Backward-compat aliases ─────────────────────────────────
  Future<void> deleteFolder(String id) async => softDelete(id);
  Future<void> deleteMany(List<String> ids) async => softDeleteMany(ids);

  /// Bersihkan folder yang sudah > 30 hari di trash. Filter client-side.
  Future<int> cleanupExpiredTrash(String userId) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final query = await _col.where('userId', isEqualTo: userId).get();
    final batch = _firestore.batch();
    int count = 0;
    for (final d in query.docs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['isDeleted'] != true) continue;
      final ts = data['deletedAt'] as Timestamp?;
      if (ts != null && ts.toDate().isBefore(cutoff)) {
        batch.delete(d.reference);
        count++;
      }
    }
    if (count > 0) await batch.commit();
    return count;
  }
}

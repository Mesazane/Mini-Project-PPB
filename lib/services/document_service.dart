// services/document_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/document_item.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('documents');

  /// Stream dokumen aktif (yang belum di-trash). Sorting di-Dart.
  Stream<List<DocumentItem>> streamDocuments(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DocumentItem.fromDoc(doc))
          .where((d) => !d.isDeleted)
          .toList();
    });
  }

  /// Stream dokumen yang ada di trash.
  Stream<List<DocumentItem>> streamTrashedDocuments(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DocumentItem.fromDoc(doc))
          .where((d) => d.isDeleted)
          .toList();
    });
  }

  Future<void> addDocument(DocumentItem item) async {
    await _col.add(item.toMap());
  }

  Future<void> updateDocument({
    required String id,
    required String title,
    required String description,
    required String fileName,
  }) async {
    await _col.doc(id).update({
      'title': title,
      'description': description,
      'fileName': fileName,
    });
  }

  Future<void> moveDocsOfFolderToRoot(String userId, String folderId) async {
    final query = await _col
        .where('userId', isEqualTo: userId)
        .where('folderId', isEqualTo: folderId)
        .get();
    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'folderId': ''});
    }
    await batch.commit();
  }

  /// Soft delete — pindahkan ke trash. File aslinya tetap ada di Firestore.
  Future<void> softDelete(DocumentItem item) async {
    await _col.doc(item.id).update({
      'isDeleted': true,
      'deletedAt': Timestamp.now(),
    });
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

  /// Restore dari trash → kembali ke aktif.
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

  /// Hapus permanen dari Firestore.
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

  // ── Backward-compat aliases (call sites yg lama) ─────────────
  /// Sekarang melakukan SOFT delete (pindah ke trash).
  Future<void> deleteDocument(DocumentItem item) async {
    await softDelete(item);
  }

  /// Sekarang melakukan SOFT delete batch.
  Future<void> deleteMany(List<String> ids) async {
    await softDeleteMany(ids);
  }

  Future<void> moveDocsToFolder(List<String> docIds, String folderId) async {
    if (docIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in docIds) {
      batch.update(_col.doc(id), {'folderId': folderId});
    }
    await batch.commit();
  }

  /// Bersihkan item yang sudah > 30 hari di trash. Filter client-side
  /// supaya tidak butuh composite index Firestore.
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

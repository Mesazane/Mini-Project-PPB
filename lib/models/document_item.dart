// models/document_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentItem {
  final String id;
  final String title;
  final String description;
  final String fileName;
  final String mediaBase64;
  final String mediaType;
  final String folderId;
  final String userId;
  final DateTime createdAt;
  final Map<String, String> metadata;
  final bool isDeleted;
  final DateTime? deletedAt;

  DocumentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.mediaBase64,
    required this.mediaType,
    required this.folderId,
    required this.userId,
    required this.createdAt,
    this.metadata = const {},
    this.isDeleted = false,
    this.deletedAt,
  });

  factory DocumentItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawMeta = data['metadata'];
    final metadata = <String, String>{};
    if (rawMeta is Map) {
      rawMeta.forEach((k, v) {
        metadata[k.toString()] = v?.toString() ?? '';
      });
    }
    return DocumentItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      fileName: data['fileName'] ?? '',
      mediaBase64: data['mediaBase64'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      folderId: data['folderId'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: metadata,
      isDeleted: data['isDeleted'] == true,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'fileName': fileName,
      'mediaBase64': mediaBase64,
      'mediaType': mediaType,
      'folderId': folderId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    };
  }
}

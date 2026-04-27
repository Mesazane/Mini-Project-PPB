// models/folder_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FolderItem {
  final String id;
  final String name;
  final int colorValue;
  final String userId;
  final String parentId;
  final DateTime createdAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  FolderItem({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
    this.colorValue = 0xFFFFC107,
    this.parentId = '',
    this.isDeleted = false,
    this.deletedAt,
  });

  Color get color => Color(colorValue);

  factory FolderItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FolderItem(
      id: doc.id,
      name: data['name'] ?? '',
      userId: data['userId'] ?? '',
      colorValue: (data['colorValue'] as num?)?.toInt() ?? 0xFFFFC107,
      parentId: data['parentId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: data['isDeleted'] == true,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorValue': colorValue,
      'userId': userId,
      'parentId': parentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    };
  }
}

const List<int> kFolderColors = [
  0xFFFFC107,
  0xFFEF5350,
  0xFFEC407A,
  0xFFAB47BC,
  0xFF7E57C2,
  0xFF5C6BC0,
  0xFF42A5F5,
  0xFF26C6DA,
  0xFF26A69A,
  0xFF66BB6A,
  0xFF9CCC65,
  0xFF8D6E63,
  0xFF78909C,
];

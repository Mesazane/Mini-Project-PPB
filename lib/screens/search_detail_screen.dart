// screens/search_detail_screen.dart

import 'package:flutter/material.dart';
import '../models/document_item.dart';
import 'widgets/cached_thumb.dart';
import 'document_detail_screen.dart';

class CategoryMediaScreen extends StatelessWidget {
  final String title;
  final List<DocumentItem> items;

  const CategoryMediaScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(item: item),
              ),
            ),
            child: CachedThumb(docId: item.id, base64Str: item.mediaBase64),
          );
        },
      ),
    );
  }
}

class CategoryListScreen extends StatelessWidget {
  final String title;
  final Map<String, List<DocumentItem>> categorizedItems;

  const CategoryListScreen({
    super.key,
    required this.title,
    required this.categorizedItems,
  });

  @override
  Widget build(BuildContext context) {
    final keys = categorizedItems.keys.toList();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: keys.length,
        itemBuilder: (ctx, i) {
          final category = keys[i];
          final items = categorizedItems[category]!;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryMediaScreen(
                  title: category,
                  items: items,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedThumb(
                      docId: items.first.id,
                      base64Str: items.first.mediaBase64,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${items.length} items',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

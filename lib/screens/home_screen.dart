// screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/document_item.dart';
import '../models/folder_item.dart';
import '../models/sort_option.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/folder_service.dart';
import '../services/geocoding_service.dart';
import '../utils/app_strings.dart';
import 'document_form_screen.dart';
import 'document_detail_screen.dart';
import 'search_detail_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/cached_thumb.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _docService = DocumentService();
  final _folderService = FolderService();

  int _currentIndex = 0; // 0: Gallery, 1: Drive, 2: Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFocused = false;

  String _currentFolderId = '';
  String _currentFolderName = '';
  final List<FolderItem> _navigationStack = [];

  ViewMode _viewMode = ViewMode.grid;
  SortOption _sortOption = SortOption.newest;

  bool _isSelecting = false;
  final Set<String> _selectedDocIds = <String>{};
  final Set<String> _selectedFolderIds = <String>{};

  // counter untuk force refresh _LocationCard saat user tekan tombol Refresh
  int _locationsRefreshCounter = 0;

  @override
  void initState() {
    super.initState();
    // Bersihkan item trash yang sudah > 30 hari (background, fire-and-forget).
    Future.microtask(() async {
      final user = _authService.currentUser;
      if (user == null) return;
      try {
        await _docService.cleanupExpiredTrash(user.uid);
        await _folderService.cleanupExpiredTrash(user.uid);
      } catch (_) {
        // ignore — kalau gagal, retry next launch
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Selection helpers ─────────────────────────────────────
  void _toggleFile(String id) {
    setState(() {
      _isSelecting = true;
      if (_selectedDocIds.contains(id)) {
        _selectedDocIds.remove(id);
        if (_selectedDocIds.isEmpty && _selectedFolderIds.isEmpty) {
          _exitSelection();
        }
      } else {
        _selectedDocIds.add(id);
      }
    });
  }

  void _toggleFolder(String id) {
    setState(() {
      _isSelecting = true;
      if (_selectedFolderIds.contains(id)) {
        _selectedFolderIds.remove(id);
        if (_selectedDocIds.isEmpty && _selectedFolderIds.isEmpty) {
          _exitSelection();
        }
      } else {
        _selectedFolderIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _isSelecting = false;
      _selectedDocIds.clear();
      _selectedFolderIds.clear();
    });
  }

  Future<void> _moveSelectedItems() async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Ambil semua folder untuk tujuan pemindahan
    final allFolders = await _folderService.streamFolders(user.uid).first;
    
    // Filter agar tidak bisa memindah folder ke dirinya sendiri atau ke dalam subfoldernya sendiri
    // (Untuk menyederhanakan, kita filter saja semua folder yang sedang di-select)
    final availableFolders = allFolders.where((f) => !_selectedFolderIds.contains(f.id)).toList();

    if (!mounted) return;

    final targetFolderId = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'move_to')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.home, color: Colors.blue),
                title: Text(AppStrings.of(ctx, 'root')),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ...availableFolders.map(
                (f) => ListTile(
                  leading: Icon(Icons.folder, color: f.color),
                  title: Text(f.name),
                  onTap: () => Navigator.pop(ctx, f.id),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.of(ctx, 'cancel')),
          ),
        ],
      ),
    );

    if (targetFolderId != null) {
      if (_selectedDocIds.isNotEmpty) {
        await _docService.moveDocsToFolder(_selectedDocIds.toList(), targetFolderId);
      }
      if (_selectedFolderIds.isNotEmpty) {
        await _folderService.moveFolders(_selectedFolderIds.toList(), targetFolderId);
      }
      
      if (!mounted) return;
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context, 'docs_moved'))),
      );
    }
  }

  Future<void> _deleteSelectedItems() async {
    final docIds = _selectedDocIds.toList();
    final folderIds = _selectedFolderIds.toList();
    final total = docIds.length + folderIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'delete_selected_title')),
        content: Text("Yakin ingin menghapus $total item terpilih?"),
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
      final user = _authService.currentUser;
      if (user == null) return;

      if (docIds.isNotEmpty) {
        await _docService.deleteMany(docIds); // soft delete
      }

      if (folderIds.isNotEmpty) {
        // folder soft-deleted, isi tetap pindah ke root supaya tidak hilang
        for (final fid in folderIds) {
          await _docService.moveDocsOfFolderToRoot(user.uid, fid);
        }
        await _folderService.deleteMany(folderIds);
      }

      if (!mounted) return;
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context, 'moved_to_trash')),
          action: SnackBarAction(
            label: AppStrings.of(context, 'restore'),
            onPressed: () async {
              await _docService.restoreMany(docIds);
              await _folderService.restoreMany(folderIds);
            },
          ),
        ),
      );
    }
  }

  Future<void> _editFolder(FolderItem folder) async {
    final nameController = TextEditingController(text: folder.name);
    int selectedColor = folder.colorValue;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.of(ctx, 'edit')),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(ctx, 'folder_name'),
                      prefixIcon: const Icon(Icons.folder),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? AppStrings.of(ctx, 'folder_name_required')
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(AppStrings.of(ctx, 'choose_color'),
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: kFolderColors.map((c) {
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 20, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.of(ctx, 'cancel')),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(AppStrings.of(ctx, 'save')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _folderService.updateFolder(
        folder.id,
        nameController.text.trim(),
        selectedColor,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context, 'folder_renamed'))),
      );
    }
  }

  // ── Single-doc & folder helpers (non-selection mode) ──────
  Future<void> _confirmDeleteDocument(DocumentItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'delete_doc_title')),
        content: Text(
            '${AppStrings.of(ctx, 'delete_doc_msg')} "${item.title}"?'),
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
      await _docService.deleteDocument(item); // soft delete -> trash
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context, 'moved_to_trash')),
          action: SnackBarAction(
            label: AppStrings.of(context, 'restore'),
            onPressed: () => _docService.restore(item.id),
          ),
        ),
      );
    }
  }

  Future<void> _showAddSheet() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.amber),
              title: Text(AppStrings.of(ctx, 'add_folder')),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateFolderDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Color(0xFF1E88E5)),
              title: Text(AppStrings.of(ctx, 'add_document')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentFormScreen(
                      initialFolderId: _currentFolderId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    final user = _authService.currentUser;
    if (user == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx, 'new_folder')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.of(ctx, 'folder_name'),
              prefixIcon: const Icon(Icons.folder),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.of(ctx, 'folder_name_required')
                : null,
            onFieldSubmitted: (v) {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, v.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.of(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(AppStrings.of(ctx, 'save')),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _folderService.addFolder(FolderItem(
          id: '',
          name: result,
          userId: user.uid,
          createdAt: DateTime.now(),
          parentId: _currentFolderId,
        ));
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.of(context, 'folder_created'))),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  // ── Sort ──────────────────────────────────────────────────
  List<DocumentItem> _sortDocs(List<DocumentItem> docs) {
    final list = [...docs];
    switch (_sortOption) {
      case SortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.nameAsc:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.nameDesc:
        list.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
    }
    return list;
  }

  // ── Tap & longpress handlers ──────────────────────────────
  void _handleDocTap(DocumentItem item) {
    if (_isSelecting) {
      _toggleFile(item.id);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(item: item),
        ),
      );
    }
  }

  void _handleDocLongPress(DocumentItem item) {
    _toggleFile(item.id);
  }

  void _handleFolderTap(FolderItem folder) {
    if (_isSelecting) {
      _toggleFolder(folder.id);
    } else {
      setState(() {
        _navigationStack.add(folder);
        _currentFolderId = folder.id;
        _currentFolderName = folder.name;
      });
    }
  }

  void _handleFolderLongPress(FolderItem folder) {
    _toggleFolder(folder.id);
  }

  void _goBack() {
    if (_navigationStack.isEmpty) return;
    setState(() {
      _navigationStack.removeLast();
      if (_navigationStack.isEmpty) {
        _currentFolderId = '';
        _currentFolderName = '';
      } else {
        final parent = _navigationStack.last;
        _currentFolderId = parent.id;
        _currentFolderName = parent.name;
      }
    });
  }

  // ── Date Grouping ──────────────────────────────────────────
  String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    if (date.year == now.year) {
      return DateFormat('EEEE, d MMMM').format(date);
    }
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }

  Map<String, List<DocumentItem>> _groupDocsByDate(List<DocumentItem> docs) {
    final Map<String, List<DocumentItem>> groups = {};
    for (var doc in docs) {
      final key = _formatGroupDate(doc.createdAt);
      groups.putIfAbsent(key, () => []).add(doc);
    }
    return groups;
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final userId = user?.uid ?? '';

    return Scaffold(
      drawer: _isSelecting ? null : const AppDrawer(),
      // AppBar muncul di semua tab (termasuk Search) supaya header app
      // & tombol drawer selalu accessible.
      appBar: _buildAppBar(context),
      // IndexedStack: semua tab tetap "alive" → StreamBuilder di tiap tab
      // tetap subscribe ke Firestore. Upload foto baru di Drive akan
      // langsung update list di Search tab tanpa perlu re-mount.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildGalleryBody(userId),
          _buildDriveBody(userId),
          _buildSearchBody(userId),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Internal: 0/1/2 -> nav bar slot 0/1/3 (slot 2 is Upload)
        currentIndex: _currentIndex < 2 ? _currentIndex : 3,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.photo_library_outlined),
            activeIcon: const Icon(Icons.photo_library),
            label: AppStrings.of(context, 'tab_gallery'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder_outlined),
            activeIcon: const Icon(Icons.folder),
            label: AppStrings.of(context, 'tab_drive'),
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add),
            ),
            label: AppStrings.of(context, 'tab_upload'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: AppStrings.of(context, 'tab_search'),
          ),
        ],
        onTap: (slot) {
          if (slot == 2) {
            _showAddSheet();
          } else if (slot == 3) {
            setState(() => _currentIndex = 2);
          } else {
            setState(() => _currentIndex = slot);
          }
        },
      ),
    );
  }

  /// Gallery: SEMUA foto/video kronologis berdasarkan tanggal, TANPA folder.
  Widget _buildGalleryBody(String userId) {
    return StreamBuilder<List<DocumentItem>>(
      stream: _docService.streamDocuments(userId),
      builder: (ctx, docSnap) {
        if (docSnap.connectionState == ConnectionState.waiting &&
            !docSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = docSnap.data ?? [];
        // sort dari yang terbaru (tanggal upload, atau tanggal diambil kalau ada)
        allDocs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (allDocs.isEmpty) return _buildEmpty();

        final groups = _groupDocsByDate(allDocs);
        final groupKeys = groups.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: groupKeys.length,
          itemBuilder: (ctx, index) {
            final dateKey = groupKeys[index];
            final groupDocs = groups[dateKey]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        dateKey,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (dateKey == 'Today' || dateKey == 'Yesterday')
                        Text(
                          '• ${DateFormat('d MMM').format(groupDocs.first.createdAt)}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 1,
                    ),
                    itemCount: groupDocs.length,
                    itemBuilder: (_, i) => _docGridCard(groupDocs[i]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Drive: folder hierarchy + files dalam folder aktif.
  Widget _buildDriveBody(String userId) {
    final isRoot = _currentFolderId.isEmpty;
    return Column(
      children: [
        if (!_isSelecting) _buildToolbar(context, isRoot),
        Expanded(
          child: StreamBuilder<List<FolderItem>>(
            stream: _folderService.streamFolders(userId,
                parentId: _currentFolderId),
            builder: (ctx, folderSnap) {
              final folders = folderSnap.data ?? [];
              return StreamBuilder<List<DocumentItem>>(
                stream: _docService.streamDocuments(userId),
                builder: (ctx, docSnap) {
                  if (docSnap.connectionState == ConnectionState.waiting &&
                      !docSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allDocs = docSnap.data ?? [];
                  final docsInScope = allDocs
                      .where((d) => d.folderId == _currentFolderId)
                      .toList();
                  final sortedDocs = _sortDocs(docsInScope);

                  if (folders.isEmpty && sortedDocs.isEmpty) {
                    return _buildEmpty();
                  }

                  if (_viewMode == ViewMode.list) {
                    return _buildList(folders, sortedDocs, isRoot);
                  }
                  return _buildGrid(folders, sortedDocs, isRoot);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBody(String userId) {
    return Stack(
      children: [
        StreamBuilder<List<DocumentItem>>(
          stream: _docService.streamDocuments(userId),
          builder: (ctx, snap) {
            final allDocs = snap.data ?? [];
            final query = _searchController.text.toLowerCase();

            if (query.isNotEmpty) {
              final results = allDocs.where((d) {
                final inTitle = d.title.toLowerCase().contains(query);
                final inFileName = d.fileName.toLowerCase().contains(query);
                final inDesc = d.description.toLowerCase().contains(query);
                // Search in metadata (device, etc)
                bool inMeta = false;
                d.metadata.forEach((k, v) {
                  if (v.toLowerCase().contains(query)) inMeta = true;
                });
                return inTitle || inFileName || inDesc || inMeta;
              }).toList();

              if (results.isEmpty) {
                return Center(child: Text(AppStrings.of(context, 'no_results')));
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: results.length,
                itemBuilder: (_, i) => _docGridCard(results[i]),
              );
            }

            // Default Search View: Categories
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              children: [
                _buildLocationsSection(allDocs),
                const SizedBox(height: 28),
                _buildSearchSection(
                  AppStrings.of(context, 'devices'),
                  allDocs,
                  (d) => d.metadata['model'],
                ),
                const SizedBox(height: 28),
                _buildSearchSection(
                  AppStrings.of(context, 'videos'),
                  allDocs,
                  (d) => d.mediaType == 'video'
                      ? AppStrings.of(context, 'videos')
                      : null,
                ),
                const SizedBox(height: 28),
                _buildSearchSection(
                  AppStrings.of(context, 'gifs'),
                  allDocs,
                  (d) => d.fileName.toLowerCase().endsWith('.gif')
                      ? AppStrings.of(context, 'gifs')
                      : null,
                ),
              ],
            );
          },
        ),
        // Floating Search Bar at Bottom
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildFloatingSearchBar(),
        ),
      ],
    );
  }

  Widget _buildFloatingSearchBar() {
    final bg = Theme.of(context).colorScheme.surfaceVariant;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(30),
      color: bg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 54,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: (v) => setState(() {}),
                decoration: InputDecoration(
                  hintText: AppStrings.of(context, 'search_hint'),
                  // Override theme's filled: true supaya tidak ada kotak
                  // background terpisah yang tidak match warna parent.
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(
    String title,
    List<DocumentItem> allDocs,
    String? Function(DocumentItem) keyExtractor,
  ) {
    final Map<String, List<DocumentItem>> categorized = {};
    for (var doc in allDocs) {
      final key = keyExtractor(doc);
      if (key != null && key.isNotEmpty) {
        categorized.putIfAbsent(key, () => []).add(doc);
      }
    }

    if (categorized.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.grey),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryListScreen(
                      title: title,
                      categorizedItems: categorized,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categorized.length,
            itemBuilder: (ctx, i) {
              final key = categorized.keys.elementAt(i);
              final items = categorized[key]!;
              final doc = items.first;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryMediaScreen(
                        title: key,
                        items: items,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: doc.mediaType == 'video'
                              ? Container(
                                  color: Colors.black87,
                                  child: const Center(
                                    child: Icon(Icons.play_circle_fill,
                                        color: Colors.white, size: 56),
                                  ),
                                )
                              : CachedThumb(
                                  docId: doc.id,
                                  base64Str: doc.mediaBase64,
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${items.length}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Section "Locations" — group docs by GPS area, pakai geocoding
  /// Nominatim untuk dapat nama tempat (free, tanpa API key).
  Widget _buildLocationsSection(List<DocumentItem> allDocs) {
    // group by rounded coords (precision 2 = ~1.1 km)
    final Map<String, List<DocumentItem>> groups = {};
    final Map<String, ({double lat, double lng})> groupCoords = {};

    for (final doc in allDocs) {
      final lat = doc.metadata['gpsLat'];
      final latRef = doc.metadata['gpsLatRef'] ?? 'N';
      final lng = doc.metadata['gpsLng'];
      final lngRef = doc.metadata['gpsLngRef'] ?? 'E';
      if (lat == null || lng == null) continue;
      final dlat = GeocodingService.parseExifGps(lat, latRef);
      final dlng = GeocodingService.parseExifGps(lng, lngRef);
      if (dlat == null || dlng == null) continue;
      final key = GeocodingService.roundedKey(dlat, dlng, precision: 2);
      groups.putIfAbsent(key, () => []).add(doc);
      groupCoords[key] = (lat: dlat, lng: dlng);
    }

    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppStrings.of(context, 'locations'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  onPressed: () {
                    GeocodingService.clearCache();
                    setState(() => _locationsRefreshCounter++);
                  },
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            itemBuilder: (ctx, i) {
              final key = groups.keys.elementAt(i);
              final items = groups[key]!;
              final coord = groupCoords[key]!;
              return _LocationCard(
                // stabilkan state per coord; counter berubah saat user
                // tekan Refresh → key berubah → widget recreate → refetch
                key: ValueKey('loc_${key}_$_locationsRefreshCounter'),
                lat: coord.lat,
                lng: coord.lng,
                items: items,
                onTap: () {},
              );
            },
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_isSelecting) {
      final total = _selectedDocIds.length + _selectedFolderIds.length;
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: AppStrings.of(context, 'cancel'),
          onPressed: _exitSelection,
        ),
        title: Text('$total ${AppStrings.of(context, 'selected')}'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_move),
            tooltip: AppStrings.of(context, 'move'),
            onPressed: _moveSelectedItems,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: AppStrings.of(context, 'delete'),
            onPressed: _deleteSelectedItems,
          ),
        ],
      );
    }
    return AppBar(
      title: Text(AppStrings.of(context, 'app_title')),
    );
  }

  Widget _buildToolbar(BuildContext context, bool isRoot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
      ),
      child: Row(
        children: [
          if (!isRoot)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: AppStrings.of(context, 'root'),
              onPressed: _goBack,
            ),
          Expanded(
            child: Row(
              children: [
                Icon(isRoot ? Icons.home : Icons.folder_open,
                    size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isRoot
                        ? AppStrings.of(context, 'root')
                        : _currentFolderName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // sort
          PopupMenuButton<SortOption>(
            tooltip: AppStrings.of(context, 'sort_by'),
            icon: const Icon(Icons.sort),
            initialValue: _sortOption,
            onSelected: (val) => setState(() => _sortOption = val),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: SortOption.newest,
                child: Text(AppStrings.of(ctx, 'sort_newest')),
              ),
              PopupMenuItem(
                value: SortOption.oldest,
                child: Text(AppStrings.of(ctx, 'sort_oldest')),
              ),
              PopupMenuItem(
                value: SortOption.nameAsc,
                child: Text(AppStrings.of(ctx, 'sort_name_asc')),
              ),
              PopupMenuItem(
                value: SortOption.nameDesc,
                child: Text(AppStrings.of(ctx, 'sort_name_desc')),
              ),
            ],
          ),
          // view mode toggle
          IconButton(
            icon: Icon(_viewMode == ViewMode.list
                ? Icons.grid_view
                : Icons.view_list),
            tooltip: _viewMode == ViewMode.list
                ? AppStrings.of(context, 'view_grid')
                : AppStrings.of(context, 'view_list'),
            onPressed: () => setState(() {
              _viewMode = _viewMode == ViewMode.list
                  ? ViewMode.grid
                  : ViewMode.list;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            AppStrings.of(context, 'no_documents'),
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.of(context, 'no_documents_hint'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── LIST VIEW ─────────────────────────────────────────────
  Widget _buildList(
    List<FolderItem> folders,
    List<DocumentItem> docs,
    bool isRoot,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (folders.isNotEmpty) ...[
          _sectionHeader(AppStrings.of(context, 'folders')),
          ...folders.map((f) => _folderTile(f)),
        ],
        if (docs.isNotEmpty) ...[
          _sectionHeader(AppStrings.of(context, 'files')),
          ...docs.map((d) => _docListTile(d)),
        ],
        if (docs.isEmpty && folders.isEmpty) _buildEmpty(),
      ],
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
    final isSelected = _selectedFolderIds.contains(folder.id);
    return Container(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6)
          : null,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.folder, color: folder.color, size: 44),
              if (_isSelecting)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _selectionMarker(isSelected),
                ),
            ],
          ),
        ),
        title: Text(folder.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            DateFormat('dd MMM yyyy').format(folder.createdAt),
            style: const TextStyle(fontSize: 12)),
        trailing: _isSelecting
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    _editFolder(folder);
                  } else if (v == 'delete') {
                    _toggleFolder(folder.id);
                    _deleteSelectedItems();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      const Icon(Icons.edit, size: 18),
                      const SizedBox(width: 8),
                      Text(AppStrings.of(ctx, 'edit')),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(AppStrings.of(ctx, 'delete'),
                          style: const TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
        onTap: () => _handleFolderTap(folder),
        onLongPress: () => _handleFolderLongPress(folder),
      ),
    );
  }

  Widget _docListTile(DocumentItem item) {
    final isVideo = item.mediaType == 'video';
    final isSelected = _selectedDocIds.contains(item.id);

    return Container(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6)
          : null,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
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
              if (_isSelecting)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _selectionMarker(isSelected),
                ),
            ],
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.fileName,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        subtitle: Text(
          DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _isSelecting
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentFormScreen(existingItem: item),
                      ),
                    );
                  } else if (v == 'delete') {
                    _confirmDeleteDocument(item);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      const Icon(Icons.edit, size: 18),
                      const SizedBox(width: 8),
                      Text(AppStrings.of(ctx, 'edit')),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(AppStrings.of(ctx, 'delete'),
                          style: const TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
        onTap: () => _handleDocTap(item),
        onLongPress: () => _handleDocLongPress(item),
      ),
    );
  }

  Widget _selectionMarker(bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 22,
        color:
            isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
    );
  }

  // ── GRID VIEW ─────────────────────────────────────────────
  Widget _buildGrid(
    List<FolderItem> folders,
    List<DocumentItem> docs,
    bool isRoot,
  ) {
    return CustomScrollView(
      slivers: [
        if (folders.isNotEmpty) ...[
          SliverToBoxAdapter(
              child: _sectionHeader(AppStrings.of(context, 'folders'))),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _folderGridCard(folders[i]),
                childCount: folders.length,
              ),
            ),
          ),
        ],
        if (docs.isNotEmpty) ...[
          SliverToBoxAdapter(
              child: _sectionHeader(AppStrings.of(context, 'files'))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _docGridCard(docs[i]),
                childCount: docs.length,
              ),
            ),
          ),
        ],
        if (docs.isEmpty && folders.isEmpty)
          SliverFillRemaining(child: _buildEmpty()),
      ],
    );
  }

  Widget _folderGridCard(FolderItem folder) {
    final isSelected = _selectedFolderIds.contains(folder.id);
    return GestureDetector(
      onTap: () => _handleFolderTap(folder),
      onLongPress: () => _handleFolderLongPress(folder),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.folder, color: folder.color, size: 36),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(folder.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            if (_isSelecting)
              Positioned(
                top: 0,
                right: 0,
                child: _selectionMarker(isSelected),
              )
            else
              Positioned(
                top: -4,
                right: -4,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _editFolder(folder);
                    } else if (v == 'delete') {
                      _toggleFolder(folder.id);
                      _deleteSelectedItems();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      height: 32,
                      child: Row(children: [
                        const Icon(Icons.edit, size: 16),
                        const SizedBox(width: 8),
                        Text(AppStrings.of(ctx, 'edit'), style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 32,
                      child: Row(children: [
                        const Icon(Icons.delete, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(AppStrings.of(ctx, 'delete'),
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _docGridCard(DocumentItem item) {
    final isVideo = item.mediaType == 'video';
    final isSelected = _selectedDocIds.contains(item.id);

    return GestureDetector(
      onTap: () => _handleDocTap(item),
      onLongPress: () => _handleDocLongPress(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          isVideo
              ? Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 32),
                  ),
                )
              : CachedThumb(
                  docId: item.id,
                  base64Str: item.mediaBase64,
                ),
          if (isVideo)
            const Positioned(
              bottom: 4,
              left: 4,
              child: Icon(Icons.videocam, color: Colors.white, size: 14),
            ),
          if (_isSelecting)
            Positioned(
              top: 4,
              right: 4,
              child: _selectionMarker(isSelected),
            ),
          if (isSelected)
            Container(color: Colors.white.withOpacity(0.2)),
        ],
      ),
    );
  }
}

/// Card untuk Locations section. Async fetch nama tempat dari Nominatim.
class _LocationCard extends StatefulWidget {
  final double lat;
  final double lng;
  final List<DocumentItem> items;
  final VoidCallback onTap;

  const _LocationCard({
    super.key,
    required this.lat,
    required this.lng,
    required this.items,
    required this.onTap,
  });

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final name =
        await GeocodingService.reverseGeocode(widget.lat, widget.lng);
    if (mounted) {
      setState(() {
        _name = name;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback =
        '${widget.lat.toStringAsFixed(2)}, ${widget.lng.toStringAsFixed(2)}';
    final label = _name ?? fallback;
    final doc = widget.items.first;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryMediaScreen(
              title: label,
              items: widget.items,
            ),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    doc.mediaType == 'video'
                        ? Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Icon(Icons.play_circle_fill,
                                  color: Colors.white, size: 56),
                            ),
                          )
                        : CachedThumb(
                            docId: doc.id, base64Str: doc.mediaBase64),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
            Text(
              '${widget.items.length}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

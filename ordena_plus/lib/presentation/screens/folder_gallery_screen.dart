import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';
import 'package:ordena_plus/presentation/providers/folder_provider.dart';
import 'package:ordena_plus/presentation/providers/folder_count_provider.dart';
import 'package:ordena_plus/presentation/providers/media_provider.dart';
import 'package:ordena_plus/presentation/widgets/media_preview.dart';
import 'package:ordena_plus/presentation/widgets/album_form_dialog.dart';
import 'package:ordena_plus/presentation/utils/icon_helper.dart';
import 'package:ordena_plus/presentation/widgets/thumbnail_widget.dart';

class FolderGalleryScreen extends ConsumerStatefulWidget {
  final String folderId;
  final String folderName;

  const FolderGalleryScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  ConsumerState<FolderGalleryScreen> createState() =>
      _FolderGalleryScreenState();
}

class _FolderGalleryScreenState extends ConsumerState<FolderGalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize = 50; // Load 50 at a time for performance

  String _currentFolderName = '';

  // Batch selection
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _currentFolderName = widget.folderName;
    _loadMedia(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMedia();
    }
  }

  Future<void> _loadMedia({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _mediaItems = [];
        _currentOffset = 0;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final repository = ref.read(mediaRepositoryProvider);
      final items = await repository.getMediaInFolder(
        widget.folderId,
        offset: _currentOffset,
        limit: _pageSize,
        newestFirst: _newestFirst,
      );

      if (mounted) {
        setState(() {
          if (items.length < _pageSize) {
            _hasMore = false;
          }

          if (refresh) {
            _mediaItems = items;
          } else {
            _mediaItems.addAll(items);
          }

          _currentOffset += items.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _newestFirst = !_newestFirst;
    });
    _loadMedia(refresh: true);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _selectAll() async {
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(_mediaItems.map((item) => item.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSystemFolder =
        widget.folderId == Folder.unorganizedId ||
        widget.folderId == Folder.trashId;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedIds.length} seleccionados',
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                _currentFolderName,
                style: const TextStyle(color: Colors.white),
              ),
        backgroundColor: Colors.teal.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null, // Default back button
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: 'Seleccionar cargados',
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              onPressed: _showMoveDialog,
              tooltip: 'Mover a otro álbum',
            ),
          ] else ...[
            // Sort Button
            IconButton(
              icon: Icon(
                _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              onPressed: _toggleSortOrder,
              tooltip: _newestFirst
                  ? 'Más recientes primero'
                  : 'Más antiguos primero',
            ),
            if (!isSystemFolder) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditDialog(),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteDialog(),
              ),
            ],
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Álbum vacío',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              // Add +1 for loading indicator if loading more
              itemCount: _mediaItems.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _mediaItems.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final item = _mediaItems[index];
                final isSelected = _selectedIds.contains(item.id);

                return GestureDetector(
                  onLongPress: () => _enterSelectionMode(item.id),
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(item.id);
                    } else {
                      _showImageViewer(context, item);
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ThumbnailWidget(mediaId: item.id, size: 200),
                      ),
                      if (_isSelectionMode)
                        Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.teal.withAlpha(100)
                                : Colors.black.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: Colors.teal, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showImageViewer(BuildContext context, dynamic mediaItem) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(200), // Blur effect background
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(child: MediaPreview(mediaItem: mediaItem)),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    final folders = ref.read(foldersProvider).value ?? [];
    final folder = folders.firstWhere((f) => f.id == widget.folderId);

    showDialog(
      context: context,
      builder: (context) => AlbumFormDialog(
        title: 'Editar Álbum',
        confirmText: 'Guardar',
        initialName: _currentFolderName,
        initialIconKey: folder.iconKey,
        initialColor: folder.color,
        onConfirm: (name, iconKey, color) async {
          final updatedFolder = folder.copyWith(
            name: name,
            iconKey: iconKey,
            color: color,
          );

          await ref.read(foldersProvider.notifier).updateFolder(updatedFolder);

          if (mounted) {
            setState(() {
              _currentFolderName = name;
            });
          }
        },
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Álbum'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este álbum definitivamente? Los archivos se moverán a "Inicio".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(foldersProvider.notifier)
                  .deleteFolder(widget.folderId);
              ref.invalidate(folderCountProvider); // Refresh counts
              ref.invalidate(unorganizedMediaProvider); // Refresh Home screen
              if (context.mounted) {
                context.go('/albums'); // Go back to albums
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final foldersState = ref.watch(foldersProvider);

          return AlertDialog(
            title: const Text('Mover a...'),
            content: SizedBox(
              width: double.maxFinite,
              child: foldersState.when(
                data: (folders) {
                  // Filter out current folder
                  final targetFolders = folders
                      .where((f) => f.id != widget.folderId)
                      .toList();

                  // Sort: Unorganized, then Trash, then others by order/creation
                  targetFolders.sort((a, b) {
                    if (a.id == Folder.unorganizedId) return -1;
                    if (b.id == Folder.unorganizedId) return 1;
                    if (a.id == Folder.trashId) return -1;
                    if (b.id == Folder.trashId) return 1;
                    return a.order.compareTo(b.order);
                  });

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: targetFolders.length,
                    itemBuilder: (context, index) {
                      final folder = targetFolders[index];

                      IconData icon;
                      Color color;

                      if (folder.id == Folder.unorganizedId) {
                        icon = Icons.home; // Use Home icon
                        color = Colors.teal; // Match app theme
                      } else if (folder.id == Folder.trashId) {
                        icon = Icons.delete;
                        color = Colors.red;
                      } else {
                        icon = IconHelper.getIcon(folder.iconKey);
                        color = folder.color != null
                            ? Color(folder.color!)
                            : Colors.teal;
                      }

                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(
                          folder.id == Folder.unorganizedId
                              ? 'Inicio' // Rename to Inicio
                              : folder.name,
                        ),
                        onTap: () async {
                          // Perform move
                          final repository = ref.read(mediaRepositoryProvider);
                          for (final mediaId in _selectedIds) {
                            await repository.assignFolder(mediaId, folder.id);
                          }

                          // Refresh counts
                          ref.invalidate(folderCountProvider);
                          ref.invalidate(unorganizedMediaProvider);

                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            _exitSelectionMode();
                            _loadMedia(refresh: true); // Reload current view
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error: $err'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

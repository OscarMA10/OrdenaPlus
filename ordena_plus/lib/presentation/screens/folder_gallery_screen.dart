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
import 'package:ordena_plus/presentation/providers/settings_provider.dart';

class FolderGalleryScreen extends ConsumerStatefulWidget {
  final String folderId;
  final String folderName;
  final String? pathPrefix;

  const FolderGalleryScreen({
    super.key,
    required this.folderId,
    required this.folderName,
    this.pathPrefix,
  });

  @override
  ConsumerState<FolderGalleryScreen> createState() =>
      _FolderGalleryScreenState();
}

class _FolderGalleryScreenState extends ConsumerState<FolderGalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  // Pagination removed for performance (Load All)

  String _currentFolderName = '';

  // Batch selection
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  bool _newestFirst = true;

  // Storage volumes for Move Dialog
  List<String> _storageVolumes = [];

  @override
  void initState() {
    super.initState();
    _currentFolderName = widget.folderName;
    _loadMedia(refresh: true);
    // _scrollController.addListener(_onScroll); // Removed pagination listener
    _fetchStorageVolumes();
  }

  Future<void> _fetchStorageVolumes() async {
    try {
      final repository = ref.read(folderRepositoryProvider);
      final volumes = await repository.getStorageVolumes();
      if (mounted) {
        setState(() {
          _storageVolumes = volumes;
        });
      }
    } catch (e) {
      debugPrint('Error fetching volumes: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      if (refresh) {
        _mediaItems = [];
      }
    });

    try {
      final repository = ref.read(mediaRepositoryProvider);
      final items = await repository.getMediaInFolder(
        widget.folderId,
        offset: 0,
        limit: 50000, // Load all (up to 50k)
        newestFirst: _newestFirst,
        pathPrefix: widget.pathPrefix,
      );

      if (mounted) {
        setState(() {
          _mediaItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
            if (widget.folderId == Folder.trashId)
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                onPressed: () =>
                    _showPermanentDeleteDialog(_selectedIds.toList()),
                tooltip: 'Eliminar definitivamente',
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
            if (widget.folderId == Folder.trashId)
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                onPressed: () => _showPermanentDeleteDialog(
                  _mediaItems.map((e) => e.id).toList(),
                  isDeleteAll: true,
                ),
                tooltip: 'Vaciar papelera',
              ),
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ref.watch(settingsProvider).gridColumns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              // Add +1 for loading indicator if loading more
              itemCount: _mediaItems.length,
              itemBuilder: (context, index) {
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
                        child: ThumbnailWidget(
                          mediaId: item.id,
                          path: item.path,
                          size: 200,
                        ),
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
              Center(
                child: MediaPreview(mediaItem: mediaItem, enableZoom: true),
              ),
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
        // For editing, we don't show storage selector (storageVolumes is empty or single)
        // The storage root is derived from folder.path
        onConfirm: (name, iconKey, color, _) async {
          // Keep the same storage root, just update the path with new name
          String? newPath;
          if (folder.path != null) {
            final parentDir = folder.path!.substring(
              0,
              folder.path!.lastIndexOf('/'),
            );
            newPath = '$parentDir/$name';
          }

          final updatedFolder = folder.copyWith(
            name: name,
            iconKey: iconKey,
            color: color,
            path: newPath,
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
          '¿Estás seguro de que quieres eliminar este álbum definitivamente? Los archivos se moverán a "Papelera".',
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

  Future<void> _showPermanentDeleteDialog(
    List<String> idsToDelete, {
    bool isDeleteAll = false,
  }) async {
    if (idsToDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isDeleteAll ? '¿Vaciar papelera?' : '¿Eliminar definitivamente?',
        ),
        content: Text(
          isDeleteAll
              ? 'Se eliminarán ${idsToDelete.length} archivos de forma permanente. Esta acción NO se puede deshacer.'
              : 'Se eliminarán ${idsToDelete.length} archivos seleccionados de forma permanente. Esta acción NO se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Use repository directly
      final repository = ref.read(mediaRepositoryProvider);

      try {
        for (final id in idsToDelete) {
          await repository.permanentlyDeleteMedia(id);
        }

        // Invalidate counts
        ref.invalidate(folderCountProvider);
        ref.invalidate(
          unorganizedMediaProvider,
        ); // In case they were unorganized-linked

        if (mounted) {
          if (_isSelectionMode) {
            _exitSelectionMode();
          }

          // Refresh current view
          _loadMedia(refresh: true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivos eliminados permanentemente'),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error permanently deleting: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  void _showMoveDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final foldersState = ref.watch(foldersProvider);

          // Manage local state for dialog
          String? selectedVolume = _storageVolumes.isNotEmpty
              ? (_storageVolumes.firstWhere(
                  (v) => v.contains('emulated/0'),
                  orElse: () => _storageVolumes.first,
                ))
              : null; // Check if we have volumes

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Mover a...'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Ruta original" Option REMOVED per user request

                      // Storage Selector (only if > 1)
                      if (_storageVolumes.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Almacenamiento',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedVolume,
                                isDense: true,
                                items: _storageVolumes.map((volume) {
                                  final label = volume.contains('emulated/0')
                                      ? 'Interno'
                                      : 'SD (${volume.split('/').last})';
                                  return DropdownMenuItem(
                                    value: volume,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedVolume = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),

                      // Folder List
                      Flexible(
                        child: foldersState.when(
                          data: (folders) {
                            // Determine if we are targeting a different volume
                            // Default to true if no context, or false if same
                            bool isDifferntVolume = false;
                            if (widget.pathPrefix != null &&
                                selectedVolume != null) {
                              isDifferntVolume = !widget.pathPrefix!.startsWith(
                                selectedVolume!,
                              );
                            } else if (selectedVolume != null &&
                                _storageVolumes.isNotEmpty) {
                              // heuristic?
                            }

                            // Filter out current folder (unless different volume for Trash)
                            // Unorganized is removed (handled by tile)
                            final targetFolders = folders.where((f) {
                              if (f.id == Folder.unorganizedId) return false;
                              if (f.id == widget.folderId) {
                                // If it's Trash and we are moving to different volume, Allow it.
                                if (f.id == Folder.trashId &&
                                    isDifferntVolume) {
                                  return true;
                                }
                                return false;
                              }
                              return true;
                            }).toList();

                            // Filter by selected volume
                            final filteredFolders = targetFolders.where((f) {
                              if (selectedVolume == null) return true;
                              // Show Trash always (system)
                              if (f.id == Folder.trashId) return true;

                              if (f.type == FolderType.system) return true;

                              if (f.path != null) {
                                return f.path!.startsWith(selectedVolume!);
                              }
                              return false;
                            }).toList();

                            // Sort
                            filteredFolders.sort((a, b) {
                              if (a.id == Folder.trashId) return -1;
                              return a.order.compareTo(b.order);
                            });

                            if (filteredFolders.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16.0),
                                child: const Text(
                                  'No hay álbumes disponibles',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredFolders.length,
                              itemBuilder: (context, index) {
                                final folder = filteredFolders[index];

                                IconData icon;
                                Color color;

                                if (folder.id == Folder.trashId) {
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
                                  title: Text(folder.name),
                                  onTap: () async {
                                    // Perform move
                                    final repository = ref.read(
                                      mediaRepositoryProvider,
                                    );
                                    for (final mediaId in _selectedIds) {
                                      await repository.assignFolder(
                                        mediaId,
                                        folder.id,
                                        destinationVolume: selectedVolume,
                                      );
                                    }

                                    // Refresh counts
                                    ref.invalidate(folderCountProvider);
                                    ref.invalidate(unorganizedMediaProvider);

                                    if (context.mounted) {
                                      Navigator.pop(context); // Close dialog
                                      _exitSelectionMode();
                                      _loadMedia(
                                        refresh: true,
                                      ); // Reload current view
                                    }
                                  },
                                );
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text('Error: $err'),
                        ),
                      ),
                    ],
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
          );
        },
      ),
    );
  }
}

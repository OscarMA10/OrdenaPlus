import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';
import 'package:ordena_plus/presentation/providers/folder_provider.dart';
import 'package:ordena_plus/presentation/providers/folder_count_provider.dart';
import 'package:ordena_plus/presentation/widgets/media_preview.dart';

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
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  String _currentFolderName = '';

  // Batch selection
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _currentFolderName = widget.folderName;
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final repository = ref.read(mediaRepositoryProvider);
    final items = await repository.getMediaInFolder(widget.folderId);
    if (mounted) {
      setState(() {
        _mediaItems = items;
        _isLoading = false;
      });
    }
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
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              onPressed: _showMoveDialog,
              tooltip: 'Mover a otro álbum',
            )
          else if (!isSystemFolder) ...[
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
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              cacheExtent: 500,
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
                        child: Image.file(
                          File(item.path),
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            );
                          },
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
    final controller = TextEditingController(text: _currentFolderName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Álbum'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nombre del álbum',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final folders = ref.read(foldersProvider).value ?? [];
                final folder = folders.firstWhere(
                  (f) => f.id == widget.folderId,
                );
                final updatedFolder = folder.copyWith(name: newName);

                await ref
                    .read(foldersProvider.notifier)
                    .updateFolder(updatedFolder);

                if (mounted) {
                  setState(() {
                    _currentFolderName = newName;
                  });
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Álbum'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este álbum definitivamente? Los archivos se moverán a "Sin organizar".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(foldersProvider.notifier).deleteFolder(widget.folderId);
              context.go('/albums'); // Go back to albums
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

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: targetFolders.length,
                    itemBuilder: (context, index) {
                      final folder = targetFolders[index];
                      return ListTile(
                        leading: Icon(
                          folder.id == Folder.trashId
                              ? Icons.delete
                              : Icons.folder,
                          color: Colors.teal,
                        ),
                        title: Text(folder.name),
                        onTap: () async {
                          // Perform move
                          final repository = ref.read(mediaRepositoryProvider);
                          for (final mediaId in _selectedIds) {
                            await repository.assignFolder(mediaId, folder.id);
                          }

                          // Refresh counts
                          ref.invalidate(folderCountProvider);

                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            _exitSelectionMode();
                            _loadMedia(); // Reload current view
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

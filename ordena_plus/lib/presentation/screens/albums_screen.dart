import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/presentation/providers/folder_provider.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/presentation/providers/folder_count_provider.dart';
import 'package:ordena_plus/presentation/providers/media_provider.dart';
import 'package:ordena_plus/presentation/widgets/album_form_dialog.dart';
import 'package:ordena_plus/presentation/utils/icon_helper.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  int _selectedIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<String> _storageVolumes = [];
  String _selectedVolume = '/storage/emulated/0';

  @override
  void initState() {
    super.initState();
    _loadStorageVolumes();
  }

  Future<void> _loadStorageVolumes() async {
    final folderRepository = ref.read(folderRepositoryProvider);
    final volumes = await folderRepository.getStorageVolumes();
    if (mounted) {
      setState(() {
        _storageVolumes = volumes;
        _selectedVolume = volumes.first;
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
    // Prevent selecting system folders
    if (id == Folder.unorganizedId || id == Folder.trashId) return;

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

  void _deleteSelectedAlbums() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${_selectedIds.length} álbumes'),
        content: const Text(
          '¿Estás seguro? Los archivos dentro de estos álbumes se moverán a "Papelera".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final idsToDelete = _selectedIds.toList();
              for (final id in idsToDelete) {
                await ref.read(foldersProvider.notifier).deleteFolder(id);
              }
              // Force refresh of counts (especially Unorganized)
              ref.invalidate(folderCountProvider);
              ref.invalidate(unorganizedMediaProvider);

              if (context.mounted) {
                Navigator.pop(context);
                _exitSelectionMode();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersState = ref.watch(foldersProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedIds.length} seleccionados',
                style: const TextStyle(color: Colors.white),
              )
            : const Text('Álbumes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade600,
        automaticallyImplyLeading: false,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedAlbums,
            )
          else
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showCreateAlbumDialog(context),
            ),
        ],
      ),
      body: foldersState.when(
        data: (folders) {
          // Reorder: Trash first, then others
          final trash = folders.firstWhere(
            (f) => f.id == Folder.trashId,
            orElse: () => const Folder(
              id: 'trash',
              name: 'Papelera',
              type: FolderType.system,
            ),
          );

          final otherFolders = folders
              .where(
                (f) => f.id != Folder.unorganizedId && f.id != Folder.trashId,
              )
              .toList();

          // Filter by selected storage volume
          final filteredFolders = otherFolders.where((f) {
            if (f.path == null) return _selectedVolume.contains('emulated/0');
            return f.path!.startsWith(_selectedVolume);
          }).toList();

          // Unorganized is hidden from this view as it is the Home screen
          final sortedFolders = [trash, ...filteredFolders];

          return Column(
            children: [
              // Storage Selector (only if multiple volumes)
              if (_storageVolumes.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storage,
                        color: Colors.teal.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Almacenamiento:',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedVolume,
                        underline: const SizedBox(),
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
                            setState(() => _selectedVolume = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: sortedFolders.length,
                  itemBuilder: (context, index) {
                    final folder = sortedFolders[index];
                    final isSelected = _selectedIds.contains(folder.id);

                    return GestureDetector(
                      onLongPress: () => _enterSelectionMode(folder.id),
                      onTap: () {
                        if (_isSelectionMode) {
                          // Prevent selecting system folders
                          if (folder.id != Folder.unorganizedId &&
                              folder.id != Folder.trashId) {
                            _toggleSelection(folder.id);
                          }
                        } else {
                          Object extra = folder.name;
                          // If accessing Trash, pass the selected volume as prefix
                          if (folder.id == Folder.trashId) {
                            extra = {
                              'name': folder.name,
                              'pathPrefix': _selectedVolume,
                            };
                          }

                          context.push('/folder/${folder.id}', extra: extra);
                        }
                      },
                      child: Stack(
                        children: [
                          _FolderCard(
                            folder: folder,
                            pathPrefix: folder.id == Folder.trashId
                                ? _selectedVolume
                                : null,
                          ),
                          if (_isSelectionMode &&
                              folder.id != Folder.unorganizedId &&
                              folder.id != Folder.trashId)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.teal
                                      : Colors.grey.withAlpha(100),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(canvasColor: Colors.teal.shade600),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          backgroundColor: Colors.teal.shade600,
          selectedFontSize: 14,
          unselectedFontSize: 12,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 1) {
              context.go('/');
            } else if (index == 2) {
              context.go('/settings');
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Álbumes'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAlbumDialog(BuildContext context) async {
    final folderRepository = ref.read(folderRepositoryProvider);
    final volumes = await folderRepository.getStorageVolumes();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlbumFormDialog(
        title: 'Nuevo Álbum',
        confirmText: 'Crear',
        storageVolumes: volumes,
        onConfirm: (name, iconKey, color, storageRoot) {
          ref
              .read(foldersProvider.notifier)
              .createFolder(name, iconKey, color, storageRoot);
        },
      ),
    );
  }
}

class _FolderCard extends ConsumerWidget {
  final Folder folder;
  final String? pathPrefix;

  const _FolderCard({required this.folder, this.pathPrefix});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      folderCountProvider(
        FolderCountParams(folderId: folder.id, pathPrefix: pathPrefix),
      ),
    );

    IconData icon;
    Color color;

    // Assign icons and colors based on folder
    if (folder.id == Folder.unorganizedId) {
      icon = Icons.inbox;
      color = Colors.orange;
    } else if (folder.id == Folder.trashId) {
      icon = Icons.delete;
      color = Colors.red;
    } else {
      icon = IconHelper.getIcon(folder.iconKey);
      color = folder.color != null ? Color(folder.color!) : Colors.teal;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              folder.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          countAsync.when(
            data: (count) => Text(
              '$count archivos',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            loading: () => const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => Text(
              'Error',
              style: TextStyle(fontSize: 12, color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
  }
}

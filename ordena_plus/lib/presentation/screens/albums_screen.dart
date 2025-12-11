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
import 'package:ordena_plus/presentation/providers/settings_provider.dart';

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

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _selectAllFolders(List<Folder> folders) {
    final query = _searchController.text.toLowerCase();

    final selectable = folders.where((f) {
      // 1. Exclude System Folders
      if (f.id == Folder.unorganizedId || f.id == Folder.trashId) return false;

      // 2. Volume Check
      bool volumeMatch;
      if (f.path == null) {
        // Fallback for folders without path (legacy/virtual?), assume internal
        volumeMatch = _selectedVolume.contains('emulated/0');
      } else {
        volumeMatch = f.path!.startsWith(_selectedVolume);
      }
      if (!volumeMatch) return false;

      // 3. Search Check
      if (_isSearching && _searchController.text.isNotEmpty) {
        if (!f.name.toLowerCase().contains(query)) return false;
      }

      return true;
    });

    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(selectable.map((e) => e.id));
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
            : _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar álbum...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() {}),
              )
            : const Text('Álbumes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade600,
        automaticallyImplyLeading: false,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              )
            : _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              onPressed: () {
                foldersState.whenData((folders) => _selectAllFolders(folders));
              },
              tooltip: 'Seleccionar todo',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedAlbums,
            ),
          ] else if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _isSearching = true),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showCreateAlbumDialog(context),
            ),
          ],
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

          var otherFolders = folders
              .where(
                (f) => f.id != Folder.unorganizedId && f.id != Folder.trashId,
              )
              .toList();

          final allFolders = [trash, ...otherFolders];

          // Apply Search Filter to ALL folders including Trash
          var searchResults = allFolders;
          if (_isSearching && _searchController.text.isNotEmpty) {
            final query = _searchController.text.toLowerCase();
            searchResults = allFolders
                .where((f) => f.name.toLowerCase().contains(query))
                .toList();
          }

          // Filter by selected storage volume
          // Note: Trash already has logic to show content based on volume elsewhere,
          // but here we might want to filter Trash if it doesn't belong to volume?
          // Actually, Trash is a single Virtual Folder ID, but its contents depend on volume.
          // So we should always show it if it matches search, or if not searching.

          final displayFolders = searchResults.where((f) {
            // Always show Trash if it's in the results (it's system)
            if (f.id == Folder.trashId) return true;

            // For others, check path prefix
            if (f.path == null) return _selectedVolume.contains('emulated/0');
            return f.path!.startsWith(_selectedVolume);
          }).toList();

          final isGrid = ref.watch(settingsProvider).isAlbumsGrid;

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
                child: isGrid
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.2,
                            ),
                        itemCount: displayFolders.length,
                        itemBuilder: (context, index) {
                          final folder = displayFolders[index];
                          final isSelected = _selectedIds.contains(folder.id);

                          return GestureDetector(
                            onLongPress: () => _enterSelectionMode(folder.id),
                            onTap: () => _handleFolderTap(folder),
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
                                    child: _buildSelectionCheck(isSelected),
                                  ),
                              ],
                            ),
                          );
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayFolders.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final folder = displayFolders[index];
                          final isSelected = _selectedIds.contains(folder.id);

                          return GestureDetector(
                            onLongPress: () => _enterSelectionMode(folder.id),
                            onTap: () => _handleFolderTap(folder),
                            child: Container(
                              color: isSelected
                                  ? Colors.teal.withAlpha(26)
                                  : Colors.transparent,
                              child: _FolderListTile(
                                folder: folder,
                                pathPrefix: folder.id == Folder.trashId
                                    ? _selectedVolume
                                    : null,
                                isSelected: isSelected,
                                isSelectionMode: _isSelectionMode,
                              ),
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

  void _handleFolderTap(Folder folder) {
    if (_isSelectionMode) {
      // Prevent selecting system folders
      if (folder.id != Folder.unorganizedId && folder.id != Folder.trashId) {
        _toggleSelection(folder.id);
      }
    } else {
      Object extra = folder.name;
      // If accessing Trash, pass the selected volume as prefix
      if (folder.id == Folder.trashId) {
        extra = {'name': folder.name, 'pathPrefix': _selectedVolume};
      }

      context.push('/folder/${folder.id}', extra: extra);
    }
  }

  Widget _buildSelectionCheck(bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal : Colors.grey.withAlpha(100),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.check,
          size: 16,
          color: isSelected ? Colors.white : Colors.transparent,
        ),
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

class _FolderListTile extends ConsumerWidget {
  final Folder folder;
  final String? pathPrefix;
  final bool isSelected;
  final bool isSelectionMode;

  const _FolderListTile({
    required this.folder,
    this.pathPrefix,
    required this.isSelected,
    required this.isSelectionMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      folderCountProvider(
        FolderCountParams(folderId: folder.id, pathPrefix: pathPrefix),
      ),
    );

    IconData icon;
    Color color;

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

    Widget? trailing;

    if (isSelectionMode) {
      if (folder.id == Folder.unorganizedId || folder.id == Folder.trashId) {
        trailing = null; // Don't show selection circle for system folders
      } else {
        trailing = isSelected
            ? const Icon(Icons.check_circle, color: Colors.teal)
            : const Icon(Icons.circle_outlined, color: Colors.grey);
      }
    } else {
      trailing = const Icon(Icons.chevron_right, color: Colors.grey);
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        folder.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: countAsync.when(
        data: (count) => Text('$count archivos'),
        loading: () => const Text('Calculando...'),
        error: (_, _) => const Text('Error'),
      ),
      trailing: trailing,
    );
  }
}

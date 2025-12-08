import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/presentation/providers/media_provider.dart';
import 'package:ordena_plus/presentation/providers/folder_provider.dart';
import 'package:ordena_plus/presentation/providers/folder_count_provider.dart';
import 'package:ordena_plus/presentation/widgets/media_preview.dart';
import 'package:ordena_plus/presentation/utils/icon_helper.dart';
import 'package:ordena_plus/presentation/widgets/album_form_dialog.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 1; // Start on Home
  bool _foldersInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize file system after first frame (after files are loaded)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFolders();
    });
  }

  Future<void> _initializeFolders() async {
    if (_foldersInitialized) return;
    _foldersInitialized = true;

    // Initialize file system (requests permission)
    final folderRepository = ref.read(folderRepositoryProvider);
    await folderRepository.initializeFileSystem();
  }

  @override
  Widget build(BuildContext context) {
    final mediaState = ref.watch(unorganizedMediaProvider);
    final foldersState = ref.watch(foldersProvider);
    final unorganizedCountAsync = ref.watch(
      folderCountProvider(Folder.unorganizedId),
    );
    final notifier = ref.read(unorganizedMediaProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade600,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Recargar archivos',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sincronizando archivos...'),
                  duration: Duration(seconds: 1),
                ),
              );

              final mediaRepository = ref.read(mediaRepositoryProvider);

              // 1. Fast Cleanup (Immediate UI update for deletions)
              await mediaRepository.cleanupDeleted();
              ref.invalidate(unorganizedMediaProvider);

              // 2. Smart Fetch (Delta sync for new files)
              await mediaRepository.fetchNewMedia();
              ref.invalidate(unorganizedMediaProvider);

              // 3. Update counter
              ref.invalidate(folderCountProvider(Folder.unorganizedId));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header: Counter and Sort
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                unorganizedCountAsync.when(
                  data: (count) => Text(
                    'Archivos sin organizar: $count',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('Error'),
                ),
                TextButton.icon(
                  onPressed: () {
                    notifier.toggleSortOrder();
                  },
                  icon: Icon(
                    notifier.isNewestFirst
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 18,
                  ),
                  label: Text(
                    notifier.isNewestFirst ? 'Recientes' : 'Antiguos',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons (Undo / Skip)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await notifier.undo();
                    ref.invalidate(folderCountProvider);
                  },
                  icon: const Icon(Icons.undo),
                  label: const Text('Deshacer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    notifier.skip();
                  },
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Omitir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),

          // Main Image Area
          Expanded(
            child: mediaState.when(
              data: (mediaItems) {
                if (mediaItems.isEmpty) {
                  return const Center(
                    child: Text(
                      '¡Todo organizado! 🎉',
                      style: TextStyle(color: Colors.black, fontSize: 24),
                    ),
                  );
                }

                final currentItem = mediaItems.first;

                return GestureDetector(
                  onTap: () => _showImageViewer(context, currentItem),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MediaPreview(mediaItem: currentItem),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
            ),
          ),

          const SizedBox(height: 16),

          // Carousel Area
          Container(
            height: 140,
            color: Colors.grey[100],
            padding: const EdgeInsets.only(bottom: 16),
            child: foldersState.when(
              data: (folders) {
                final trash = folders.firstWhere(
                  (f) => f.id == Folder.trashId,
                  orElse: () => const Folder(
                    id: 'trash',
                    name: 'Papelera',
                    iconKey: 'delete',
                    type: FolderType.system,
                  ),
                );

                final otherFolders = folders
                    .where(
                      (f) =>
                          f.id != Folder.unorganizedId &&
                          f.id != Folder.trashId,
                    )
                    .toList();

                final carouselFolders = [trash, ...otherFolders];

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: carouselFolders.length + 1, // +1 for Create button
                  itemBuilder: (context, index) {
                    if (index == carouselFolders.length) {
                      return GestureDetector(
                        onTap: () => _showCreateAlbumDialog(context),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.shade200,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 32,
                                color: Colors.teal.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nuevo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final folder = carouselFolders[index];
                    return _CarouselItem(
                      folder: folder,
                      onTap: () async {
                        final currentItems = mediaState.value;
                        if (currentItems != null && currentItems.isNotEmpty) {
                          await notifier.assignFolder(
                            currentItems.first.id,
                            folder.id,
                          );
                          ref.invalidate(folderCountProvider);
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
          ),
        ],
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
            if (index == 0) {
              context.go('/albums');
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

  void _showImageViewer(BuildContext context, dynamic mediaItem) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(200),
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

  void _showCreateAlbumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlbumFormDialog(
        title: 'Nuevo Álbum',
        confirmText: 'Crear',
        onConfirm: (name, iconKey, color) {
          ref.read(foldersProvider.notifier).createFolder(name, iconKey, color);
        },
      ),
    );
  }
}

class _CarouselItem extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;

  const _CarouselItem({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    if (folder.id == Folder.trashId) {
      icon = Icons.delete;
      color = Colors.red;
    } else {
      icon = IconHelper.getIcon(folder.iconKey);
      color = folder.color != null ? Color(folder.color!) : Colors.teal;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                folder.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

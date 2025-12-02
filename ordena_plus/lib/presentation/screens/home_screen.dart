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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 1; // Start on Home

  @override
  Widget build(BuildContext context) {
    final mediaState = ref.watch(unorganizedMediaProvider);
    final foldersState = ref.watch(foldersProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade600,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              if (Platform.isAndroid) {
                SystemNavigator.pop();
              } else {
                exit(0);
              }
            },
          ),
        ],
      ),
      body: mediaState.when(
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

          return Stack(
            children: [
              // Full size image area (Background)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _showImageViewer(context, currentItem),
                  child: Container(
                    color: Colors.grey[100],
                    child: MediaPreview(mediaItem: currentItem),
                  ),
                ),
              ),

              // Undo Button (Top Left)
              Positioned(
                top: 16,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withAlpha(200),
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.undo, color: Colors.black87),
                    onPressed: () {
                      ref.read(unorganizedMediaProvider.notifier).undo();
                      ref.invalidate(folderCountProvider);
                    },
                  ),
                ),
              ),

              // Skip Button (Top Right)
              Positioned(
                top: 16,
                right: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withAlpha(200),
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.black87),
                    onPressed: () {
                      ref.read(unorganizedMediaProvider.notifier).skip();
                    },
                  ),
                ),
              ),

              // Carousel area (Bottom Overlay)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withAlpha(150), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: foldersState.when(
                    data: (folders) {
                      final trash = folders.firstWhere(
                        (f) => f.id == Folder.trashId,
                        orElse: () => const Folder(
                          id: 'trash',
                          name: 'Papelera',
                          iconPath: '',
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
                        itemCount: carouselFolders.length,
                        itemBuilder: (context, index) {
                          final folder = carouselFolders[index];
                          return _CarouselItem(
                            folder: folder,
                            onTap: () {
                              ref
                                  .read(unorganizedMediaProvider.notifier)
                                  .assignFolder(currentItem.id, folder.id);
                              ref.invalidate(folderCountProvider);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
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
    } else if (folder.name.toLowerCase().contains('foto')) {
      icon = Icons.photo_library;
      color = Colors.blue;
    } else if (folder.name.toLowerCase().contains('video') ||
        folder.name.toLowerCase().contains('vídeo')) {
      icon = Icons.video_library;
      color = Colors.purple;
    } else {
      icon = Icons.folder;
      color = Colors.teal;
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
              color: Colors.black.withAlpha(50),
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

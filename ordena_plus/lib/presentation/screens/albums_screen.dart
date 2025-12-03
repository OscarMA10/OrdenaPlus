import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/presentation/providers/folder_provider.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/presentation/providers/folder_count_provider.dart';
import 'package:ordena_plus/presentation/widgets/album_form_dialog.dart';

class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final foldersState = ref.watch(foldersProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Álbumes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade600,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showCreateAlbumDialog(context),
          ),
        ],
      ),
      body: foldersState.when(
        data: (folders) {
          // Reorder: Unorganized first, then Trash, then others
          final unorganized = folders.firstWhere(
            (f) => f.id == Folder.unorganizedId,
            orElse: () => const Folder(
              id: 'unorganized',
              name: 'Sin organizar',
              iconPath: 'assets/icons/inbox.png',
              type: FolderType.system,
            ),
          );

          final trash = folders.firstWhere(
            (f) => f.id == Folder.trashId,
            orElse: () => const Folder(
              id: 'trash',
              name: 'Papelera',
              iconPath: 'assets/icons/trash.png',
              type: FolderType.system,
            ),
          );

          final otherFolders = folders
              .where(
                (f) => f.id != Folder.unorganizedId && f.id != Folder.trashId,
              )
              .toList();

          final sortedFolders = [unorganized, trash, ...otherFolders];

          return GridView.builder(
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
              return _FolderCard(folder: folder);
            },
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

class _FolderCard extends ConsumerWidget {
  final Folder folder;

  const _FolderCard({required this.folder});

  // Helper to get IconData from key
  IconData _getIconData(String? key) {
    const icons = {
      'folder': Icons.folder,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'work': Icons.work,
      'flight': Icons.flight,
      'home': Icons.home,
      'school': Icons.school,
      'pets': Icons.pets,
      'sports_soccer': Icons.sports_soccer,
      'music_note': Icons.music_note,
      'movie': Icons.movie,
      'camera_alt': Icons.camera_alt,
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'beach_access': Icons.beach_access,
      'fitness_center': Icons.fitness_center,
      'gamepad': Icons.gamepad,
      'book': Icons.book,
      'lightbulb': Icons.lightbulb,
    };
    return icons[key] ?? Icons.folder;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(folderCountProvider(folder.id));

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
      // Use custom properties if available, otherwise fallback
      icon = _getIconData(folder.iconKey);
      color = folder.color != null ? Color(folder.color!) : Colors.teal;
    }

    return GestureDetector(
      onTap: () {
        context.push('/folder/${folder.id}', extra: folder.name);
      },
      child: Container(
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
              error: (_, __) => Text(
                'Error',
                style: TextStyle(fontSize: 12, color: Colors.red.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/presentation/providers/folder_provider.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/presentation/providers/folder_count_provider.dart';

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
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Álbum'),
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
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(foldersProvider.notifier).createFolder(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends ConsumerWidget {
  final Folder folder;

  const _FolderCard({required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(folderCountProvider(folder.id));

    IconData icon;
    Color color;

    // Assign icons and colors based on folder
    switch (folder.id) {
      case 'unorganized':
        icon = Icons.inbox;
        color = Colors.orange;
        break;
      case 'trash':
        icon = Icons.delete;
        color = Colors.red;
        break;
      default:
        // Check folder name for default folders
        if (folder.name.toLowerCase().contains('foto')) {
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
            Text(
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/presentation/providers/folder_provider.dart';

class WheelWidget extends ConsumerWidget {
  final List<Folder> folders;
  final Function(String) onFolderSelected;

  const WheelWidget({
    super.key,
    required this.folders,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Basic implementation: Horizontal list for MVP
    // TODO: Implement actual circular wheel
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withAlpha(204), Colors.transparent],
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: folders.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          if (index == folders.length) {
            // Create Folder Button
            return GestureDetector(
              onTap: () => _showCreateFolderDialog(context, ref),
              child: Container(
                width: 100,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 32),
                    SizedBox(height: 4),
                    Text(
                      'Crear',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          final folder = folders[index];
          return DragTarget<String>(
            onWillAcceptWithDetails: (data) => true,
            onAcceptWithDetails: (data) {
              onFolderSelected(folder.id);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return Container(
                width: 100,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                decoration: BoxDecoration(
                  color: isHovered
                      ? Colors.blue.withAlpha(128)
                      : Colors.grey[800],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHovered ? Colors.blue : Colors.white,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconForFolder(folder),
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      folder.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Carpeta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nombre de la carpeta'),
          autofocus: true,
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

  IconData _getIconForFolder(Folder folder) {
    switch (folder.id) {
      case Folder.trashId:
        return Icons.delete;
      case Folder.photosId:
        return Icons.photo;
      case Folder.videosId:
        return Icons.videocam;
      case Folder.unorganizedId:
        return Icons.inbox;
      default:
        return Icons.folder;
    }
  }
}

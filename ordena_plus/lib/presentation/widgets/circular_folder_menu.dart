import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/domain/models/folder.dart';

class CircularFolderMenu extends ConsumerWidget {
  final List<Folder> folders;
  final Function(String) onFolderSelected;

  const CircularFolderMenu({
    super.key,
    required this.folders,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    // Move center up by 50 pixels to align with screen center
    final center = Offset(size.width / 2, (size.height / 2) - 50);
    final radius = min(size.width, size.height) * 0.38;

    // Filter out system folders
    final customFolders = folders
        .where((f) => f.id != Folder.unorganizedId && f.id != Folder.trashId)
        .toList();

    final totalItems = customFolders.length;
    final angleStep = (2 * pi) / totalItems;

    return Stack(
      children: [
        // Background circle to make menu visible
        Center(
          child: Container(
            width: radius * 2 + 100,
            height: radius * 2 + 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
          ),
        ),

        // Folder labels around circle - TAP TO ASSIGN
        for (int i = 0; i < totalItems; i++) ...[
          Builder(
            builder: (context) {
              final folder = customFolders[i];
              final angle = i * angleStep - (pi / 2); // Start from top
              final x = center.dx + radius * cos(angle);
              final y = center.dy + radius * sin(angle);

              return Positioned(
                left: x - 50,
                top: y - 15,
                child: GestureDetector(
                  onTap: () {
                    // TAP TO ASSIGN - no drag needed
                    onFolderSelected(folder.id);
                  },
                  onLongPress: () {
                    // Navigate to folder gallery on long press
                    context.push('/folder/${folder.id}', extra: folder.name);
                  },
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      folder.name,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ],

        // Trash ICON at bottom center
        Positioned(
          left: center.dx - 30,
          bottom: 60,
          child: GestureDetector(
            onTap: () {
              onFolderSelected(Folder.trashId);
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.delete_outline,
                color: Colors.grey.shade700,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

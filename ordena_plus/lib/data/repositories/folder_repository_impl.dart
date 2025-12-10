import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ordena_plus/data/datasources/local/database_helper.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/repositories/folder_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';

class FolderRepositoryImpl implements FolderRepository {
  final DatabaseHelper _dbHelper;

  FolderRepositoryImpl(this._dbHelper);

  // Request storage permission (called lazily, not at startup)
  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  @override
  Future<List<String>> getStorageVolumes() async {
    try {
      // Returns list like ["/storage/emulated/0", "/storage/B3AE-4D28"]
      final volumes = await ExternalPath.getExternalStorageDirectories();
      return volumes ?? ['/storage/emulated/0'];
    } catch (e) {
      debugPrint('Error getting storage volumes: $e');
      return ['/storage/emulated/0']; // Fallback to internal
    }
  }

  @override
  Future<void> initializeFileSystem() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      debugPrint('Storage permission denied - cannot create folders');
      return;
    }

    try {
      // Ensure 'Ordena+' exists on ALL detected volumes
      final volumes = await getStorageVolumes();
      for (final volume in volumes) {
        final rootDir = Directory('$volume/Pictures/Ordena+');
        if (!await rootDir.exists()) {
          await rootDir.create(recursive: true);
        }

        // Trash is only needed on the volume where files are being managed,
        // but creating it everywhere is safer for simplicity.
        final trashDir = Directory('${rootDir.path}/Papelera');
        if (!await trashDir.exists()) {
          await trashDir.create();
        }
      }
    } catch (e) {
      debugPrint('Error initializing file system: $e');
    }
  }

  @override
  Future<List<Folder>> getFolders() async {
    final db = await _dbHelper.database;
    final result = await db.query('folders', orderBy: '"order" ASC');
    return result.map((map) => Folder.fromMap(map)).toList();
  }

  @override
  Future<void> createFolder(Folder folder) async {
    final db = await _dbHelper.database;
    await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Create physical folder
    // Now we rely on folder.path being set correctly by logic layer (UI or UseCase)
    if (folder.type != FolderType.system && folder.path != null) {
      try {
        final newDir = Directory(folder.path!);
        if (!await newDir.exists()) {
          await newDir.create(recursive: true);
        }
      } catch (e) {
        debugPrint('Error creating physical folder: $e');
      }
    }
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    final db = await _dbHelper.database;
    final oldFolder = await getFolderById(folder.id);

    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );

    // Rename physical folder
    if (folder.type != FolderType.system &&
        oldFolder != null &&
        (oldFolder.name != folder.name || oldFolder.path != folder.path)) {
      try {
        // If paths are different (e.g. moved or renamed)
        if (oldFolder.path != null && folder.path != null) {
          final oldDir = Directory(oldFolder.path!);
          final newDir = Directory(folder.path!);

          if (await oldDir.exists()) {
            await oldDir.rename(newDir.path);

            // UPDATE MEDIA PATHS IN DB
            final itemsToUpdate = await db.query(
              'media_items',
              where: 'folderId = ?',
              whereArgs: [folder.id],
            );

            if (itemsToUpdate.isNotEmpty) {
              final batch = db.batch();
              for (final item in itemsToUpdate) {
                final oldPath = item['path'] as String;
                final String fileName = Uri.file(oldPath).pathSegments.last;
                final String newPath = '${newDir.path}/$fileName';

                batch.update(
                  'media_items',
                  {'path': newPath},
                  where: 'id = ?',
                  whereArgs: [item['id']],
                );
              }
              await batch.commit(noResult: true);
            }
          } else {
            // If old dir doesn't exist, just create new one
            await newDir.create(recursive: true);
          }
        }
      } catch (e) {
        debugPrint('Error renaming physical folder: $e');
      }
    }
  }

  @override
  Future<void> deleteFolder(String id) async {
    final folder = await getFolderById(id);
    final db = await _dbHelper.database;

    // 1. SAFE DELETE & MOVE: Move files physically to Unorganized (Internal Root for now)
    // NOTE: If file is on SD card, it should move to "Unorganized" on SD card?
    // Current design has ONE Unorganized root (Internal).
    // Moving from SD -> Internal on Delete is a cross-volume move (Slow).
    // Better strategy: "Unorganized" is virtual. Just move them to root of the same volume?
    // ALLOWED SIMPLIFICATION: Move all to Internal Root.

    if (folder != null && folder.type != FolderType.system) {
      final itemsToMove = await db.query(
        'media_items',
        where: 'folderId = ?',
        whereArgs: [id],
      );

      // Target: Trash Folder (Per Volume)
      final batch = db.batch();

      for (final item in itemsToMove) {
        final oldPath = item['path'] as String;
        final mediaId = item['id'] as String;
        final file = File(oldPath);

        if (await file.exists()) {
          // 1. Determine Volume Root
          String volumeRoot;
          if (oldPath.startsWith('/storage/emulated/0')) {
            volumeRoot = '/storage/emulated/0';
          } else {
            final match = RegExp(
              r'^/storage/[A-Za-z0-9-]+',
            ).firstMatch(oldPath);
            volumeRoot = match?.group(0) ?? '/storage/emulated/0';
          }

          // 2. Determine Trash Path
          final trashDir = Directory('$volumeRoot/Pictures/Ordena+/Papelera');
          if (!await trashDir.exists()) {
            await trashDir.create(recursive: true);
          }

          String fileName = file.uri.pathSegments.last;
          String newPath = '${trashDir.path}/$fileName';

          // Collision check
          if (await File(newPath).exists() && File(newPath).path != file.path) {
            final nameWithoutExtension = fileName.substring(
              0,
              fileName.lastIndexOf('.'),
            );
            final extension = fileName.substring(fileName.lastIndexOf('.'));
            int counter = 1;
            while (await File(newPath).exists()) {
              newPath =
                  '${trashDir.path}/${nameWithoutExtension}_$counter$extension';
              counter++;
            }
          }

          if (newPath != oldPath) {
            try {
              // Try rename first
              await file.rename(newPath);
              batch.update(
                'media_items',
                {'folderId': Folder.trashId, 'path': newPath},
                where: 'id = ?',
                whereArgs: [mediaId],
              );
            } catch (e) {
              // Cross-volume fallback (shouldn't happen with correct volume logic, but safety)
              try {
                await file.copy(newPath);
                await file.delete();
                batch.update(
                  'media_items',
                  {'folderId': Folder.trashId, 'path': newPath},
                  where: 'id = ?',
                  whereArgs: [mediaId],
                );
              } catch (e2) {
                debugPrint('Failed to move file ${file.path}: $e2');
                // Keep record but mark trash
                batch.update(
                  'media_items',
                  {'folderId': Folder.trashId},
                  where: 'id = ?',
                  whereArgs: [mediaId],
                );
              }
            }
          } else {
            // Path didn't change (already in trash? unlikely if in album)
            batch.update(
              'media_items',
              {'folderId': Folder.trashId},
              where: 'id = ?',
              whereArgs: [mediaId],
            );
          }
        } else {
          // File missing, just update DB to trash so it doesn't show in album (which is being deleted)
          batch.update(
            'media_items',
            {'folderId': Folder.trashId},
            where: 'id = ?',
            whereArgs: [mediaId],
          );
        }
      }
      await batch.commit(noResult: true);
    }

    // 2. Delete Folder Record
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);

    // 3. Delete Physical Folder
    if (folder != null &&
        folder.type != FolderType.system &&
        folder.path != null) {
      try {
        final dir = Directory(folder.path!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('Error deleting physical folder: $e');
      }
    }
  }

  @override
  Future<Folder?> getFolderById(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Folder.fromMap(result.first);
    }
    return null;
  }
}

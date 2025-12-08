import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ordena_plus/data/datasources/local/database_helper.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/repositories/folder_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Future<void> initializeFileSystem() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      debugPrint('Storage permission denied - cannot create folders');
      return;
    }

    try {
      final rootDir = Directory('/storage/emulated/0/Pictures/Ordena+');
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }

      final trashDir = Directory('${rootDir.path}/Papelera');
      if (!await trashDir.exists()) {
        await trashDir.create();
      }
    } catch (e) {
      debugPrint('Error initializing file system: $e');
    }
  }

  Future<Directory> _getAppFolder() async {
    final directory = Directory('/storage/emulated/0/Pictures/Ordena+');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
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

    // Create physical folder (permission already granted or will fail silently)
    if (folder.type != FolderType.system) {
      try {
        final appDir = await _getAppFolder();
        final newDir = Directory('${appDir.path}/${folder.name}');
        if (!await newDir.exists()) {
          await newDir.create();
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
    // Rename physical folder
    if (folder.type != FolderType.system &&
        oldFolder != null &&
        oldFolder.name != folder.name) {
      try {
        final appDir = await _getAppFolder();
        final oldDir = Directory('${appDir.path}/${oldFolder.name}');
        final newDir = Directory('${appDir.path}/${folder.name}');

        if (await oldDir.exists()) {
          await oldDir.rename(newDir.path);

          // UPDATE MEDIA PATHS IN DB
          // Fetch all items in this folder
          final itemsToUpdate = await db.query(
            'media_items',
            where: 'folderId = ?',
            whereArgs: [folder.id],
          );

          if (itemsToUpdate.isNotEmpty) {
            final batch = db.batch();
            for (final item in itemsToUpdate) {
              final oldPath = item['path'] as String;
              // Careful with separators. Assuming standard usage.
              // We can rely on URI parsing or simple split.
              // Actually, since we know the new directory path, we just append the filename.
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
          await newDir.create();
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

    // 1. SAFE DELETE & MOVE: Move files physically to root ("Inicio") and update DB
    if (folder != null && folder.type != FolderType.system) {
      // Get items strictly from DB to ensure we only move what we know about
      // and update their paths immediately
      final itemsToMove = await db.query(
        'media_items',
        where: 'folderId = ?',
        whereArgs: [id],
      );

      final appDir = await _getAppFolder();
      final batch = db.batch();

      for (final item in itemsToMove) {
        final oldPath = item['path'] as String;
        final file = File(oldPath);

        if (await file.exists()) {
          String fileName = file.uri.pathSegments.last;
          String newPath = '${appDir.path}/$fileName';

          // Handle collision at root
          if (await File(newPath).exists() && File(newPath).path != file.path) {
            final nameWithoutExtension = fileName.substring(
              0,
              fileName.lastIndexOf('.'),
            );
            final extension = fileName.substring(fileName.lastIndexOf('.'));
            int counter = 1;
            while (await File(newPath).exists()) {
              newPath =
                  '${appDir.path}/${nameWithoutExtension}_$counter$extension';
              counter++;
            }
          }

          // Only move if paths are different
          if (newPath != oldPath) {
            try {
              await file.rename(newPath);
              // Update path and folderId in DB
              batch.update(
                'media_items',
                {'folderId': Folder.unorganizedId, 'path': newPath},
                where: 'id = ?',
                whereArgs: [item['id']],
              );
            } catch (e) {
              debugPrint('Failed to move file ${file.path}: $e');
              batch.update(
                'media_items',
                {'folderId': Folder.unorganizedId},
                where: 'id = ?',
                whereArgs: [item['id']],
              );
            }
          } else {
            batch.update(
              'media_items',
              {'folderId': Folder.unorganizedId},
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          }
        } else {
          // File doesn't exist on disk? Update DB to Unorganized
          batch.update(
            'media_items',
            {'folderId': Folder.unorganizedId},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
      }
      await batch.commit(noResult: true);
    }

    // 3. Delete the folder record (transaction)
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);

    // 4. Delete physical folder (now empty-ish)
    if (folder != null && folder.type != FolderType.system) {
      try {
        final appDir = await _getAppFolder();
        final dir = Directory('${appDir.path}/${folder.name}');
        if (await dir.exists()) {
          // Recursive true is now safer as we moved known files, but trash/other files might remain?
          // The user expects the folder gone.
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

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
    if (folder.type != FolderType.system &&
        oldFolder != null &&
        oldFolder.name != folder.name) {
      try {
        final appDir = await _getAppFolder();
        final oldDir = Directory('${appDir.path}/${oldFolder.name}');
        final newDir = Directory('${appDir.path}/${folder.name}');

        if (await oldDir.exists()) {
          await oldDir.rename(newDir.path);
        } else {
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

    await db.transaction((txn) async {
      await txn.update(
        'media_items',
        {'folderId': Folder.unorganizedId},
        where: 'folderId = ?',
        whereArgs: [id],
      );
      await txn.delete('folders', where: 'id = ?', whereArgs: [id]);
    });

    // Delete physical folder
    if (folder != null && folder.type != FolderType.system) {
      try {
        final appDir = await _getAppFolder();
        final dir = Directory('${appDir.path}/${folder.name}');
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

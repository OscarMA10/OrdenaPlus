import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ordena_plus/data/datasources/local/database_helper.dart';
import 'package:ordena_plus/data/datasources/device/media_service.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/repositories/media_repository.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';

class MediaRepositoryImpl implements MediaRepository {
  final DatabaseHelper _dbHelper;
  final MediaService _mediaService;

  MediaRepositoryImpl(this._dbHelper, this._mediaService);

  @override
  Future<List<MediaItem>> getMediaItems({
    int offset = 0,
    int limit = 50,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'media_items',
      limit: limit,
      offset: offset,
      orderBy: 'dateCreated DESC',
    );
    return maps.map((map) => MediaItem.fromMap(map)).toList();
  }

  @override
  Future<List<MediaItem>> getUnorganizedMedia({
    int offset = 0,
    int limit = 1000,
    bool newestFirst = true,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'media_items',
      where: 'folderId = ?',
      whereArgs: [Folder.unorganizedId],
      limit: limit,
      offset: offset,
      orderBy: newestFirst ? 'dateCreated DESC' : 'dateCreated ASC',
    );
    return maps.map((map) => MediaItem.fromMap(map)).toList();
  }

  @override
  Future<int> getUnorganizedCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM media_items WHERE folderId = ?',
      [Folder.unorganizedId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<MediaItem>> getMediaInFolder(
    String folderId, {
    int offset = 0,
    int limit = 1000,
    bool newestFirst = true,
    String? pathPrefix,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'folderId = ?';
    List<Object?> whereArgs = [folderId];

    if (pathPrefix != null) {
      whereClause += ' AND path LIKE ?';
      whereArgs.add('$pathPrefix%');
    }

    final result = await db.query(
      'media_items',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: newestFirst ? 'dateCreated DESC' : 'dateCreated ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((map) => MediaItem.fromMap(map)).toList();
  }

  @override
  Future<void> assignFolder(
    String mediaId,
    String folderId, {
    String? destinationVolume,
  }) async {
    final db = await _dbHelper.database;

    // 1. Get current media item to find source path
    final mediaResult = await db.query(
      'media_items',
      columns: ['path'],
      where: 'id = ?',
      whereArgs: [mediaId],
    );
    if (mediaResult.isEmpty) return;
    final String currentPath = mediaResult.first['path'] as String;
    final File sourceFile = File(currentPath);

    if (!await sourceFile.exists()) {
      debugPrint('File not found for move: $currentPath');
      await _updateMediaFolderInDb(db, mediaId, folderId, currentPath);
      return;
    }

    // 2. Determine destination directory
    String destDirPath;

    // Determine target volume root
    String volumeRoot;

    if (destinationVolume != null) {
      // Explicit destination (e.g. from Move Dialog)
      // Ensure specific format if it's "emulated/0" or SD path
      volumeRoot = destinationVolume;
    } else {
      // Implicit: Keep on same volume as source
      if (currentPath.startsWith('/storage/emulated/0')) {
        volumeRoot = '/storage/emulated/0';
      } else {
        // Regex for SD card: /storage/ABCD-1234
        final match = RegExp(
          r'^/storage/[A-Za-z0-9-]+',
        ).firstMatch(currentPath);
        if (match != null) {
          volumeRoot = match.group(0)!;
        } else {
          volumeRoot = '/storage/emulated/0'; // Fallback
        }
      }
    }

    final String appRootPath = '$volumeRoot/Pictures/Ordena+';

    if (folderId == Folder.unorganizedId) {
      // Unorganized goes to App Root on the same volume
      destDirPath = appRootPath;
    } else if (folderId == Folder.trashId) {
      // Trash goes to .trashed/Papelera on the same volume (or just Papelera)
      // Using standard Papelera folder as before
      destDirPath = '$appRootPath/Papelera';
    } else {
      // Custom Album: Get folder path from DB (supports SD card)
      final folderResult = await db.query(
        'folders',
        columns: ['name', 'path'],
        where: 'id = ?',
        whereArgs: [folderId],
      );
      if (folderResult.isNotEmpty) {
        final folderPath = folderResult.first['path'] as String?;
        final folderName = folderResult.first['name'] as String;
        // Use explicit path if available, otherwise construct from app root
        destDirPath = folderPath ?? '$appRootPath/$folderName';
      } else {
        // Folder not found? Fallback to root
        destDirPath = appRootPath;
      }
    }

    // Ensure destination directory exists
    final Directory destDir = Directory(destDirPath);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    // 3. Construct new path and handle collisions
    String fileName = sourceFile.uri.pathSegments.last;
    String newPath = '$destDirPath/$fileName';

    // Check if moving to same location
    if (File(newPath).path == sourceFile.path) {
      // Same path, just update DB folderId (in case it was wrong)
      await _updateMediaFolderInDb(db, mediaId, folderId, newPath);
      return;
    }

    // Handle name collision
    if (await File(newPath).exists()) {
      final nameWithoutExtension = fileName.substring(
        0,
        fileName.lastIndexOf('.'),
      );
      final extension = fileName.substring(fileName.lastIndexOf('.'));
      int counter = 1;
      while (await File(newPath).exists()) {
        newPath = '$destDirPath/${nameWithoutExtension}_$counter$extension';
        counter++;
      }
    }

    // 4. Move the file
    try {
      await sourceFile.rename(newPath);

      // 5. Update Database with new path and folderId
      await _updateMediaFolderInDb(db, mediaId, folderId, newPath);
    } catch (e) {
      debugPrint('Error moving file: $e');
      // If rename fails (e.g. cross-device), try copy + delete
      try {
        await sourceFile.copy(newPath);
        await sourceFile.delete();
        await _updateMediaFolderInDb(db, mediaId, folderId, newPath);
      } catch (e2) {
        debugPrint('Error copying file: $e2');
        // Failed to move, do not update DB
      }
    }
  }

  Future<void> _updateMediaFolderInDb(
    Database db,
    String mediaId,
    String folderId,
    String path,
  ) async {
    await db.update(
      'media_items',
      {'folderId': folderId, 'path': path},
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  @override
  Future<void> syncMedia() async {
    await for (final _ in syncWithProgress()) {}
  }

  @override
  Stream<double> syncWithProgress() async* {
    final db = await _dbHelper.database;

    // ULTRA-FAST PATH: If DB already has items, skip sync entirely!
    final dbCountResult = await db.rawQuery(
      'SELECT COUNT(*) as c FROM media_items',
    );
    final dbCount = Sqflite.firstIntValue(dbCountResult) ?? 0;

    if (dbCount > 0) {
      yield 1.0;
      return;
    }

    // FIRST TIME ONLY: Need to sync from device
    final hasPermission = await _mediaService.requestPermission();
    if (!hasPermission) {
      yield 1.0;
      return;
    }

    final deviceCount = await _mediaService.getAssetCount();
    if (deviceCount == 0) {
      yield 1.0;
      return;
    }

    const int pageSize = 200;
    int page = 0;
    int processed = 0;

    while (processed < deviceCount) {
      final assets = await _mediaService.fetchAssets(
        page: page,
        size: pageSize,
      );
      if (assets.isEmpty) break;

      final batch = db.batch();
      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        final mediaItem = MediaItem(
          id: asset.id,
          path: file.path,
          type: asset.type == AssetType.video
              ? MediaType.video
              : MediaType.photo,
          dateCreated: asset.createDateTime,
          folderId: Folder.unorganizedId,
          originalPath: file.path,
        );

        batch.insert(
          'media_items',
          mediaItem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);

      processed += assets.length;
      page++;
      yield processed / deviceCount;
    }

    yield 1.0;
  }

  @override
  Future<void> cleanupDeleted() async {
    final hasPermission = await _mediaService.requestPermission();
    if (!hasPermission) return;

    final db = await _dbHelper.database;

    // FAST CLEANUP: Check if files still exist on disk
    final allMedia = await db.query('media_items', columns: ['id', 'path']);
    final batchCleanup = db.batch();
    bool needsCleanup = false;
    int count = 0;

    for (final item in allMedia) {
      final path = item['path'] as String;
      final id = item['id'] as String;

      final file = File(path);
      if (!file.existsSync()) {
        batchCleanup.delete('media_items', where: 'id = ?', whereArgs: [id]);
        needsCleanup = true;
      }

      // Yield to UI thread every 50 items to prevent freeze
      count++;
      if (count % 50 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    if (needsCleanup) {
      await batchCleanup.commit(noResult: true);
    }
  }

  @override
  Future<void> fetchNewMedia() async {
    final hasPermission = await _mediaService.requestPermission();
    if (!hasPermission) return;

    final db = await _dbHelper.database;

    // Get the date of the newest media item in DB
    final result = await db.query(
      'media_items',
      columns: ['dateCreated'],
      orderBy: 'dateCreated DESC',
      limit: 1,
    );

    DateTime? lastDate;
    if (result.isNotEmpty && result.first['dateCreated'] != null) {
      final timestamp = result.first['dateCreated'] as int;
      // Add 1 second to avoid fetching the same last item
      lastDate = DateTime.fromMillisecondsSinceEpoch(
        timestamp,
      ).add(const Duration(seconds: 1));
    } else {
      // If DB is empty, fetch everything (fallback to old method or use very old date)
      lastDate = DateTime(1970);
    }

    // Fetch ONLY new assets from device
    final newAssets = await _mediaService.fetchNewAssets(lastDate);

    if (newAssets.isNotEmpty) {
      final batch = db.batch();
      for (final asset in newAssets) {
        final file = await asset.file;
        if (file == null) continue;

        final mediaItem = MediaItem(
          id: asset.id,
          path: file.path,
          type: asset.type == AssetType.video
              ? MediaType.video
              : MediaType.photo,
          dateCreated: asset.createDateTime,
          folderId: Folder.unorganizedId,
          originalPath: file.path,
        );

        batch.insert(
          'media_items',
          mediaItem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    await assignFolder(mediaId, Folder.trashId);
  }

  @override
  Future<void> permanentlyDeleteMedia(String mediaId) async {
    final db = await _dbHelper.database;

    // 1. Get file path
    final mediaResult = await db.query(
      'media_items',
      columns: ['path'],
      where: 'id = ?',
      whereArgs: [mediaId],
    );

    if (mediaResult.isNotEmpty) {
      final path = mediaResult.first['path'] as String;
      final file = File(path);

      // 2. Delete physical file
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('Error deleting file permanently: $e');
          // Proceed to delete from DB anyway?
          // Yes, if we can't delete the file (e.g. permission),
          // we might still want to remove it from app if it's "phantom".
          // But strict behavior is better.
          // For now, let's assume if it fails, we throw or return.
          // But to avoid "stuck" items, we usually continue.
        }
      }
    }

    // 3. Delete from DB
    await db.delete('media_items', where: 'id = ?', whereArgs: [mediaId]);
  }

  @override
  Future<void> restoreMedia(
    String mediaId, {
    String? targetPath,
    String? targetFolderId,
  }) async {
    final db = await _dbHelper.database;
    final mediaResult = await db.query(
      'media_items',
      columns: ['path', 'originalPath'],
      where: 'id = ?',
      whereArgs: [mediaId],
    );

    if (mediaResult.isEmpty) return;
    final String currentPath = mediaResult.first['path'] as String;
    final String? originalPath = mediaResult.first['originalPath'] as String?;
    final File sourceFile = File(currentPath);

    if (!await sourceFile.exists()) {
      return;
    }

    // Determine target path logic
    String effectiveTargetPath;

    if (originalPath != null &&
        originalPath.isNotEmpty &&
        originalPath != currentPath) {
      // Priority 1: Use persistent original path
      effectiveTargetPath = originalPath;
    } else if (targetPath != null &&
        targetPath.isNotEmpty &&
        targetPath != currentPath) {
      // Priority 2: Use implicit target path (from Undo)
      effectiveTargetPath = targetPath;
    } else {
      // Priority 3: Fallback (Safe Restore)
      // If we are here, we don't know where to go, or "original" == "current" (legacy).
      // We MUST move it out of the current folder to proper "Unorganized" location.
      // Default: VolumeRoot/Pictures/Ordena+/Restored/filename.jpg

      // 1. Determine Volume Root
      String volumeRoot;
      if (currentPath.startsWith('/storage/emulated/0')) {
        volumeRoot = '/storage/emulated/0';
      } else {
        final match = RegExp(
          r'^/storage/[A-Za-z0-9-]+',
        ).firstMatch(currentPath);
        volumeRoot = match?.group(0) ?? '/storage/emulated/0';
      }

      final restoreDir = Directory('$volumeRoot/Pictures/Ordena+/Restored');
      if (!await restoreDir.exists()) {
        await restoreDir.create(recursive: true);
      }

      String fileName = currentPath.split('/').last;
      effectiveTargetPath = '${restoreDir.path}/$fileName';
    }

    // Ensure target dir exists
    final targetDir = Directory(File(effectiveTargetPath).parent.path);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    String finalPath = effectiveTargetPath;

    // Collision check at target
    if (await File(finalPath).exists() && finalPath != currentPath) {
      // Suffix
      String fileName = finalPath.split('/').last;
      String dir = finalPath.substring(0, finalPath.lastIndexOf('/'));
      String name = fileName.substring(0, fileName.lastIndexOf('.'));
      String ext = fileName.substring(fileName.lastIndexOf('.'));
      int counter = 1;
      while (await File(finalPath).exists()) {
        finalPath = '$dir/${name}_$counter$ext';
        counter++;
      }
    }

    if (finalPath != currentPath) {
      try {
        await sourceFile.rename(finalPath);
      } catch (e) {
        // Fallback for cross-volume or permission issues
        try {
          await sourceFile.copy(finalPath);
          await sourceFile.delete();
        } catch (e2) {
          debugPrint('Failed to restore file: $e2');
          // Update DB to reflect failure? Or keep old path?
          // If copy failed, we shouldn't update DB to new path.
          return;
        }
      }
    }

    await db.update(
      'media_items',
      {'path': finalPath, 'folderId': targetFolderId ?? Folder.unorganizedId},
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  @override
  Future<int> getMediaCountInFolder(
    String folderId, {
    String? pathPrefix,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'folderId = ?';
    List<Object?> whereArgs = [folderId];

    if (pathPrefix != null) {
      whereClause += ' AND path LIKE ?';
      whereArgs.add('$pathPrefix%');
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM media_items WHERE $whereClause',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'media_items',
      where: 'id = ?',
      whereArgs: [mediaId],
    );

    if (results.isNotEmpty) {
      return MediaItem.fromMap(results.first);
    }
    return null;
  }

  @override
  Future<void> insertMediaItem(MediaItem item) async {
    final db = await _dbHelper.database;
    await db.insert(
      'media_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<bool> existsByPath(String path) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'media_items',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> clearDatabase() async {
    // LOGICAL RESET: Just wipe DB tables.
    // Filesystem remains as-is, app treats all files as unorganized.
    // syncMedia() will re-populate unorganized items.

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('media_items');
      await txn.delete(
        'folders',
        where: 'id NOT IN (?, ?)',
        whereArgs: [Folder.unorganizedId, Folder.trashId],
      );
    });
  }
}

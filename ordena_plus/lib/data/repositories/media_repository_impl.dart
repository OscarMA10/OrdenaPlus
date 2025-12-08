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
  }) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'media_items',
      where: 'folderId = ?',
      whereArgs: [folderId],
      orderBy: newestFirst ? 'dateCreated DESC' : 'dateCreated ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((map) => MediaItem.fromMap(map)).toList();
  }

  @override
  Future<void> assignFolder(String mediaId, String folderId) async {
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
    const String rootPath = '/storage/emulated/0/Pictures/Ordena+';

    if (folderId == Folder.unorganizedId) {
      destDirPath = rootPath;
    } else if (folderId == Folder.trashId) {
      destDirPath = '$rootPath/Papelera';
    } else {
      // Custom Album: Get folder name
      final folderResult = await db.query(
        'folders',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [folderId],
      );
      if (folderResult.isNotEmpty) {
        final folderName = folderResult.first['name'] as String;
        destDirPath = '$rootPath/$folderName';
      } else {
        // Folder not found? Fallback to root
        destDirPath = rootPath;
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
  Future<int> getMediaCountInFolder(String folderId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM media_items WHERE folderId = ?',
      [folderId],
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

import 'dart:async';
import 'dart:io';
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
    await db.update(
      'media_items',
      {'folderId': folderId},
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
}

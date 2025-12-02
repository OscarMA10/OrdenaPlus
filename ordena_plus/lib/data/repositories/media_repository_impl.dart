import 'dart:async';
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
    int limit = 50,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'media_items',
      where: 'folderId = ?',
      whereArgs: [Folder.unorganizedId],
      limit: limit,
      offset: offset,
      orderBy: 'dateCreated DESC',
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
    int limit = 50,
  }) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'media_items',
      where: 'folderId = ?',
      whereArgs: [folderId],
      orderBy: 'dateCreated DESC',
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
    await for (final _ in syncWithProgress()) {
      // Consume stream until done
    }
  }

  @override
  Stream<double> syncWithProgress() async* {
    final hasPermission = await _mediaService.requestPermission();
    if (!hasPermission) {
      yield 1.0;
      return;
    }

    final assets = await _mediaService.fetchAssets();
    if (assets.isEmpty) {
      yield 1.0;
      return;
    }

    final db = await _dbHelper.database;
    final batch = db.batch();

    // Process in chunks to avoid UI freeze and report progress
    const int chunkSize = 100;
    int processed = 0;

    for (var i = 0; i < assets.length; i += chunkSize) {
      final end = (i + chunkSize < assets.length)
          ? i + chunkSize
          : assets.length;
      final chunk = assets.sublist(i, end);

      for (final asset in chunk) {
        final file = await asset.file;
        if (file == null) continue;

        final mediaItem = MediaItem(
          id: asset.id,
          path: file.path,
          type: asset.type == AssetType.video
              ? MediaType.video
              : MediaType.photo,
          dateCreated: asset.createDateTime,
          folderId: Folder.unorganizedId, // Default to unorganized
        );

        batch.insert(
          'media_items',
          mediaItem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await batch.commit(noResult: true);
      processed += chunk.length;
      yield processed / assets.length;
    }

    yield 1.0;
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

import 'package:ordena_plus/domain/models/media_item.dart';

abstract class MediaRepository {
  Future<List<MediaItem>> getMediaItems({int offset = 0, int limit = 50});
  Future<List<MediaItem>> getUnorganizedMedia({
    int offset = 0,
    int limit = 1000,
    bool newestFirst = true,
  });
  Future<int> getUnorganizedCount(); // Get total count without pagination
  Future<List<MediaItem>> getMediaInFolder(
    String folderId, {
    int offset = 0,
    int limit = 50,
    bool newestFirst = true,
    String? pathPrefix,
  });
  Future<void> assignFolder(
    String mediaId,
    String folderId, {
    String? destinationVolume,
  });
  Future<void> syncMedia(); // Syncs device media with local DB
  Stream<double> syncWithProgress(); // Syncs with progress stream (0.0 to 1.0)
  Future<void> deleteMedia(String mediaId); // Move to trash or delete
  Future<void> permanentlyDeleteMedia(
    String mediaId,
  ); // Permanently delete from device
  Future<void> restoreMedia(
    String mediaId, {
    String? targetPath,
    String? targetFolderId,
  });
  Future<int> getMediaCountInFolder(String folderId, {String? pathPrefix});
  Future<void> cleanupDeleted(); // Fast cleanup of deleted files
  Future<void> fetchNewMedia(); // Smart fetch of new files
  Future<MediaItem?> getMediaItem(String mediaId); // Get single media item
  Future<void> insertMediaItem(
    MediaItem item,
  ); // Insert a media item directly (for debug)
  Future<bool> existsByPath(String path); // Check if media exists by path
  Future<void> clearDatabase(); // Reset all data
}

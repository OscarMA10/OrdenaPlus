import 'package:ordena_plus/domain/models/media_item.dart';

abstract class MediaRepository {
  Future<List<MediaItem>> getMediaItems({int offset = 0, int limit = 50});
  Future<List<MediaItem>> getUnorganizedMedia({int offset = 0, int limit = 50});
  Future<int> getUnorganizedCount(); // Get total count without pagination
  Future<List<MediaItem>> getMediaInFolder(
    String folderId, {
    int offset = 0,
    int limit = 50,
  });
  Future<void> assignFolder(String mediaId, String folderId);
  Future<void> syncMedia(); // Syncs device media with local DB
  Stream<double> syncWithProgress(); // Syncs with progress stream (0.0 to 1.0)
  Future<void> deleteMedia(String mediaId); // Move to trash or delete
  Future<int> getMediaCountInFolder(String folderId);
}

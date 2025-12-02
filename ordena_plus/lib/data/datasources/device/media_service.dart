import 'package:photo_manager/photo_manager.dart';

class MediaService {
  Future<bool> requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  Future<List<AssetEntity>> fetchAssets({int page = 0, int size = 50}) async {
    // Fetch all albums
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Image and Video
      hasAll: true,
    );

    if (albums.isEmpty) return [];

    // Get the "Recent" album (usually the first one)
    final AssetPathEntity recentAlbum = albums.first;

    // Fetch assets from the album
    final List<AssetEntity> assets = await recentAlbum.getAssetListPaged(
      page: page,
      size: size,
    );

    return assets;
  }

  Future<List<AssetEntity>> fetchAllAssets() async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );
    if (albums.isEmpty) return [];
    final AssetPathEntity recentAlbum = albums.first;
    final int assetCount = await recentAlbum.assetCountAsync;
    return await recentAlbum.getAssetListRange(start: 0, end: assetCount);
  }
}

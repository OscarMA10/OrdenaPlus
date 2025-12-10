import 'package:ordena_plus/domain/models/folder.dart';

abstract class FolderRepository {
  Future<List<Folder>> getFolders();
  Future<void> createFolder(Folder folder);
  Future<void> updateFolder(Folder folder);
  Future<void> deleteFolder(String id);
  Future<Folder?> getFolderById(String id);
  Future<List<String>> getStorageVolumes();
  Future<void> initializeFileSystem();
}

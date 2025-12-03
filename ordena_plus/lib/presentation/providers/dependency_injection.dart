import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/data/datasources/device/media_service.dart';
import 'package:ordena_plus/data/datasources/local/database_helper.dart';
import 'package:ordena_plus/data/repositories/folder_repository_impl.dart';
import 'package:ordena_plus/data/repositories/media_repository_impl.dart';
import 'package:ordena_plus/domain/repositories/folder_repository.dart';
import 'package:ordena_plus/domain/repositories/media_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService();
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final mediaService = ref.watch(mediaServiceProvider);
  return MediaRepositoryImpl(dbHelper, mediaService);
});

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return FolderRepositoryImpl(dbHelper);
});

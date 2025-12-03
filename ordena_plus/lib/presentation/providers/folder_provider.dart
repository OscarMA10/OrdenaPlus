import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/repositories/folder_repository.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

final foldersProvider =
    StateNotifierProvider<FoldersNotifier, AsyncValue<List<Folder>>>((ref) {
      final repository = ref.watch(folderRepositoryProvider);
      return FoldersNotifier(repository);
    });

class FoldersNotifier extends StateNotifier<AsyncValue<List<Folder>>> {
  final FolderRepository _repository;

  FoldersNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadFolders();
  }

  Future<void> loadFolders() async {
    try {
      final folders = await _repository.getFolders();
      state = AsyncValue.data(folders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createFolder(String name, String iconKey, int color) async {
    try {
      final currentFolders = state.value ?? [];
      final newFolder = Folder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        iconKey: iconKey,
        color: color,
        type: FolderType.custom,
        order: currentFolders.length,
      );
      await _repository.createFolder(newFolder);
      await loadFolders();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteFolder(String folderId) async {
    try {
      await _repository.deleteFolder(folderId);
      final currentFolders = state.value ?? [];
      state = AsyncValue.data(
        currentFolders.where((f) => f.id != folderId).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateFolder(Folder folder) async {
    try {
      await _repository.updateFolder(folder);
      await loadFolders(); // Reload to reflect changes
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

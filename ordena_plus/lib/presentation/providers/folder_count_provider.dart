import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

class FolderCountParams {
  final String folderId;
  final String? pathPrefix;

  const FolderCountParams({required this.folderId, this.pathPrefix});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderCountParams &&
        other.folderId == folderId &&
        other.pathPrefix == pathPrefix;
  }

  @override
  int get hashCode => Object.hash(folderId, pathPrefix);
}

final folderCountProvider = FutureProvider.family<int, FolderCountParams>((
  ref,
  params,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaCountInFolder(
    params.folderId,
    pathPrefix: params.pathPrefix,
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

final folderCountProvider = FutureProvider.family<int, String>((
  ref,
  folderId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaCountInFolder(folderId);
});

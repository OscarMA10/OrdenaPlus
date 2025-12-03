import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:ordena_plus/domain/repositories/media_repository.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

// State to hold media list and sort preference
class UnorganizedMediaState {
  final AsyncValue<List<MediaItem>> media;
  final bool newestFirst;

  UnorganizedMediaState({required this.media, this.newestFirst = true});

  UnorganizedMediaState copyWith({
    AsyncValue<List<MediaItem>>? media,
    bool? newestFirst,
  }) {
    return UnorganizedMediaState(
      media: media ?? this.media,
      newestFirst: newestFirst ?? this.newestFirst,
    );
  }
}

final unorganizedMediaProvider =
    StateNotifierProvider<
      UnorganizedMediaNotifier,
      AsyncValue<List<MediaItem>>
    >((ref) {
      final repository = ref.watch(mediaRepositoryProvider);
      return UnorganizedMediaNotifier(repository);
    });

// Separate provider for Sort Order if we want to toggle it easily
final sortOrderProvider = StateProvider<bool>(
  (ref) => true,
); // true = newest first

class UnorganizedMediaNotifier
    extends StateNotifier<AsyncValue<List<MediaItem>>> {
  final MediaRepository _repository;
  bool _newestFirst = true;

  UnorganizedMediaNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    loadMedia();
  }

  Future<void> loadMedia() async {
    try {
      state = const AsyncValue.loading();
      final items = await _repository.getUnorganizedMedia(
        newestFirst: _newestFirst,
        limit: 1000, // Increased limit
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void toggleSortOrder() {
    _newestFirst = !_newestFirst;
    loadMedia();
  }

  bool get isNewestFirst => _newestFirst;

  Future<void> assignFolder(String mediaId, String folderId) async {
    try {
      await _repository.assignFolder(mediaId, folderId);
      // Optimistic update
      final currentItems = state.value ?? [];
      state = AsyncValue.data(
        currentItems.where((item) => item.id != mediaId).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> undo() async {
    // Implement undo logic if we track history
    // For now, just reload to be safe or implement history stack
    await loadMedia();
  }

  void skip() {
    final currentItems = state.value ?? [];
    if (currentItems.isNotEmpty) {
      // Move first item to end of list locally
      final first = currentItems.first;
      final rest = currentItems.sublist(1);
      state = AsyncValue.data([...rest, first]);
    }
  }
}

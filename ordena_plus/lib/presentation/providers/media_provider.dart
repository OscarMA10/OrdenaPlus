import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:ordena_plus/domain/models/folder.dart';
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
  final List<MediaAction> _history = [];
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
      final currentItems = state.value ?? [];
      final itemIndex = currentItems.indexWhere((i) => i.id == mediaId);

      if (itemIndex == -1) return;

      final item = currentItems[itemIndex];

      // Optimistic update
      final updatedList = List<MediaItem>.from(currentItems)
        ..removeAt(itemIndex);
      state = AsyncValue.data(updatedList);

      // Add to history
      _history.add(
        MediaAction(
          item: item,
          folderId: folderId,
          actionType: ActionType.assign,
        ),
      );

      await _repository.assignFolder(mediaId, folderId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      loadMedia(); // Reload on error
    }
  }

  Future<void> undo() async {
    if (_history.isEmpty) return;

    final lastAction = _history.removeLast();
    try {
      if (lastAction.actionType == ActionType.assign) {
        // Revert folder assignment
        await _repository.assignFolder(
          lastAction.item.id,
          Folder.unorganizedId,
        );

        // Add back to the BEGINNING of the list (or correct position based on sort?)
        // For simplicity, add to beginning as user expects to see it back
        final currentItems = state.value ?? [];
        state = AsyncValue.data([lastAction.item, ...currentItems]);
      } else if (lastAction.actionType == ActionType.skip) {
        // Undo skip: move item from end back to beginning
        final currentItems = state.value ?? [];
        final itemIndex = currentItems.indexWhere(
          (i) => i.id == lastAction.item.id,
        );

        if (itemIndex != -1) {
          final updatedList = List<MediaItem>.from(currentItems)
            ..removeAt(itemIndex);
          state = AsyncValue.data([lastAction.item, ...updatedList]);
        }
      }
    } catch (e) {
      loadMedia(); // Reload on error
    }
  }

  void skip() {
    final currentItems = state.value ?? [];
    if (currentItems.isNotEmpty) {
      // Move first item to end of list locally
      final first = currentItems.first;
      final rest = currentItems.sublist(1);
      state = AsyncValue.data([...rest, first]);

      _history.add(MediaAction(item: first, actionType: ActionType.skip));
    }
  }
}

enum ActionType { assign, skip }

class MediaAction {
  final MediaItem item;
  final String? folderId;
  final ActionType actionType;

  MediaAction({required this.item, this.folderId, required this.actionType});
}

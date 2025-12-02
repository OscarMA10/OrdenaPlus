import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/repositories/media_repository.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

final unorganizedMediaProvider =
    StateNotifierProvider<
      UnorganizedMediaNotifier,
      AsyncValue<List<MediaItem>>
    >((ref) {
      final repository = ref.watch(mediaRepositoryProvider);
      return UnorganizedMediaNotifier(repository);
    });

class UnorganizedMediaNotifier
    extends StateNotifier<AsyncValue<List<MediaItem>>> {
  final MediaRepository _repository;
  final List<MediaAction> _history = [];
  int _currentOffset = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;

  UnorganizedMediaNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    syncAndLoad();
  }

  Future<void> syncAndLoad() async {
    try {
      // Sync in background, but start loading immediately
      _repository.syncMedia().then((_) => loadMore(refresh: true));
      await loadMore(refresh: true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore({bool refresh = false}) async {
    if (refresh) {
      _currentOffset = 0;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (!_hasMore) return;

    try {
      final newItems = await _repository.getUnorganizedMedia(
        offset: _currentOffset,
        limit: _pageSize,
      );

      if (newItems.length < _pageSize) {
        _hasMore = false;
      }

      _currentOffset += newItems.length;

      final currentList = state.value ?? [];
      if (refresh) {
        state = AsyncValue.data(newItems);
      } else {
        state = AsyncValue.data([...currentList, ...newItems]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> assignFolder(String mediaId, String folderId) async {
    try {
      final currentItems = state.value ?? [];
      final itemIndex = currentItems.indexWhere((i) => i.id == mediaId);

      if (itemIndex == -1) return;

      final item = currentItems[itemIndex];

      // Optimistic update: Remove from list locally
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

      // Perform DB update
      await _repository.assignFolder(mediaId, folderId);

      // Load more if running low
      if (updatedList.length < 5 && _hasMore) {
        loadMore();
      }
    } catch (e) {
      // Revert on error (simplified)
      loadMore(refresh: true);
    }
  }

  Future<void> skip() async {
    final currentItems = state.value ?? [];
    if (currentItems.isEmpty) return;

    // Rotate first item to end
    final item = currentItems.first;
    final updatedList = [...currentItems.sublist(1), item];
    state = AsyncValue.data(updatedList);

    // Track skip action in history
    _history.add(MediaAction(item: item, actionType: ActionType.skip));
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

        // Add back to the BEGINNING of the list
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
      // Handle error
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

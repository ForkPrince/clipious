import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/settings/models/errors/invidious_service_error.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:clipious/videos/states/hidden_videos.dart';

import '../models/paginated_list.dart';

part 'item_list.freezed.dart';

enum ItemListErrors { none, couldNotFetchItems, invalidScope }

class ItemListCubit<T> extends Cubit<ItemListState<T>> {
  final ScrollController scrollController = ScrollController();
  StreamSubscription? _hiddenSub;
  Timer? _loadMoreTimer;
  bool _loading = false;
  Completer<void>? _loadComplete;
  Future<List<T>> Function()? _failedLoad;

  ItemListCubit(super.initialState) {
    onReady();
    if (state.itemList is SubscriptionVideoList) {
      _hiddenSub = HiddenVideosCubit.instance.stream.listen((hiddenState) {
        removeWhere((item) =>
            item is Video && hiddenState.hiddenIds.contains(item.videoId));
      });
    }
  }

  @override
  close() async {
    _loadMoreTimer?.cancel();
    _failedLoad = null;
    await _hiddenSub?.cancel();
    scrollController.dispose();
    super.close();
  }

  void onReady() {
    getItems();
    scrollController.addListener(onScrollEvent);
  }

  void onScrollEvent() {
    if (!isClosed && !_loading && state.itemList.getHasMore()) {
      if (!scrollController.hasClients) return;
      if (scrollController.position.maxScrollExtent * 0.9 <
          scrollController.offset) {
        _loadMoreTimer?.cancel();
        _loadMoreTimer = Timer(const Duration(milliseconds: 500), getMoreItems);
      }
    }
  }

  Future<void> getMoreItems() async {
    if (!isClosed && !_loading && state.itemList.getHasMore()) {
      await loadItems(() async {
        List<T> items = await state.itemList.getMoreItems();
        List<T> currentItems = List.from(state.items)..addAll(items);
        return currentItems;
      });
    }
  }

  Future<void> refreshItems() async {
    await _loadComplete?.future;
    await loadItems(state.itemList.refresh);
  }

  void removeWhere(bool Function(T) test) {
    if (isClosed) return;
    var items = state.items.where((e) => !test(e)).toList();
    if (items.length != state.items.length) {
      emit(state.copyWith(items: items));
    }
  }

  Future<void> getItems() async {
    await loadItems(state.itemList.getItems);
  }

  /// Retry the failed request without resetting its page or continuation.
  Future<void> retryItems() async {
    final request = _failedLoad;
    if (request != null) await loadItems(request);
  }

  Future<void> loadItems(Future<List<T>> Function() refreshFunction) async {
    if (isClosed || _loading) return;
    _loadMoreTimer?.cancel();
    _loading = true;
    _failedLoad = null;
    final completion = _loadComplete = Completer<void>();
    emit(state.copyWith(error: ItemListErrors.none, loading: true));
    try {
      var items = await refreshFunction();
      if (!isClosed) {
        emit(state.copyWith(loading: false, items: items));
      }
    } catch (err) {
      late ItemListErrors error;
      if (err is InvidiousServiceError && err.message == "Invalid scope") {
        error = ItemListErrors.invalidScope;
      } else {
        error = ItemListErrors.couldNotFetchItems;
      }
      if (!isClosed) {
        _failedLoad = refreshFunction;
        emit(state.copyWith(error: error, loading: false));
      }
    } finally {
      _loading = false;
      _loadComplete = null;
      completion.complete();
    }
  }

  // similar
  void focusChanged(bool value, int index) {}
}

@freezed
sealed class ItemListState<T> with _$ItemListState<T> {
  const factory ItemListState({
    required PaginatedList<T> itemList,
    @Default([]) List<T> items,
    @Default(true) bool loading,
    @Default(ItemListErrors.none) ItemListErrors error,
  }) = _ItemListState<T>;
}

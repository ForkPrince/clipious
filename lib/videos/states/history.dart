import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/utils/states/item_list.dart';
import 'package:clipious/videos/models/dearrow.dart';

import '../models/db/history_video_cache.dart';

part 'history.freezed.dart';

class HistoryCubit extends Cubit<void> {
  final ItemListCubit<String> historyListCubit;

  HistoryCubit(super.initialState, this.historyListCubit);

  removeFromHistory(String videoId) async {
    await service.deleteFromUserHistory(videoId);
    historyListCubit.refreshItems();
  }

  clearHistory() async {
    await service.clearUserHistory();
    historyListCubit.refreshItems();
  }
}

class HistoryItemCubit extends Cubit<HistoryItemState> {
  HistoryItemCubit(super.initialState) {
    onReady();
  }

  void onReady() {
    getVideo();
  }

  getVideo() async {
    emit(state.copyWith(loading: true));

    var cachedVid = await HistoryVideoCache.fromVideoIdToVideo(state.videoId);

    if (!isClosed) {
      emit(state.copyWith(cachedVid: cachedVid, loading: false));
    }

    try {
      var deArrowed = await DeArrow.processVideo(cachedVid.toVideo());
      if (!isClosed &&
          (deArrowed.title != cachedVid.title ||
              (deArrowed.deArrowThumbnailUrl != null &&
                  deArrowed.deArrowThumbnailUrl != cachedVid.thumbnail))) {
        var updated = HistoryVideoCache(
            cachedVid.videoId,
            deArrowed.title ?? cachedVid.title,
            cachedVid.author,
            deArrowed.deArrowThumbnailUrl ?? cachedVid.thumbnail)
          ..created = cachedVid.created;
        await db.upsertHistoryVideo(updated);
        if (!isClosed) emit(state.copyWith(cachedVid: updated));
      }
    } catch (_) {}
  }
}

@freezed
sealed class HistoryItemState with _$HistoryItemState {
  const factory HistoryItemState(
      {required String videoId,
      @Default(true) bool loading,
      HistoryVideoCache? cachedVid}) = _HistoryItemState;
}

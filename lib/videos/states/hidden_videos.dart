import 'package:bloc/bloc.dart';
import 'package:clipious/globals.dart';

class HiddenVideosState {
  final Set<String> hiddenIds;
  final bool loading;
  final bool loaded;

  const HiddenVideosState(
      {this.hiddenIds = const {}, this.loading = false, this.loaded = false});

  HiddenVideosState copyWith(
      {Set<String>? hiddenIds, bool? loading, bool? loaded}) {
    return HiddenVideosState(
        hiddenIds: hiddenIds ?? this.hiddenIds,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded);
  }
}

class HiddenVideosCubit extends Cubit<HiddenVideosState> {
  static final HiddenVideosCubit instance =
      HiddenVideosCubit(const HiddenVideosState());

  HiddenVideosCubit(super.initialState);

  bool isHidden(String videoId) => state.hiddenIds.contains(videoId);

  Future<void> ensureLoaded() async {
    if (state.loaded || state.loading || isClosed) return;
    emit(state.copyWith(loading: true));
    try {
      if (!await service.supportsHidden()) {
        if (!isClosed) emit(state.copyWith(loading: false, loaded: true));
        return;
      }
      var ids = <String>{};
      var page = 1;
      while (true) {
        var batch = await service.getHiddenVideos(page, 100);
        ids.addAll(batch);
        if (batch.length < 100) break;
        page++;
      }
      if (!isClosed) {
        emit(state.copyWith(hiddenIds: ids, loading: false, loaded: true));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loading: false));
    }
  }

  Future<bool> hideVideo(String videoId) async {
    if (state.hiddenIds.contains(videoId)) return true;
    emit(state.copyWith(hiddenIds: {...state.hiddenIds, videoId}));
    var ok = await service.hideVideo(videoId);
    if (!ok && !isClosed) {
      var ids = Set<String>.from(state.hiddenIds)..remove(videoId);
      emit(state.copyWith(hiddenIds: ids));
    }
    return ok;
  }

  Future<bool> unhideVideo(String videoId) async {
    if (!state.hiddenIds.contains(videoId)) {
      return service.unhideVideo(videoId);
    }
    var ids = Set<String>.from(state.hiddenIds)..remove(videoId);
    emit(state.copyWith(hiddenIds: ids));
    var ok = await service.unhideVideo(videoId);
    if (!ok && !isClosed) {
      emit(state.copyWith(hiddenIds: {...state.hiddenIds, videoId}));
    }
    return ok;
  }
}

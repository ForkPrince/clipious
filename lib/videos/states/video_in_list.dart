import 'package:bloc/bloc.dart';
import 'package:clipious/videos/models/dearrow.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/downloads/models/downloaded_video.dart';

import '../../globals.dart';

part 'video_in_list.freezed.dart';

class VideoInListCubit extends Cubit<VideoInListState> {
  VideoInListCubit(super.initialState) {
    onReady();
  }

  onReady() {
    updateProgress();
    maybeDeArrow();
  }

  Future<void> maybeDeArrow() async {
    var v = state.video;
    if (v == null || v.deArrowed) return;
    try {
      var updated = await DeArrow.processVideo(v);
      if (!isClosed &&
          (updated.title != v.title ||
              updated.deArrowThumbnailUrl != v.deArrowThumbnailUrl)) {
        emit(state.copyWith(video: updated));
      }
    } catch (_) {}
  }

  updateProgress() {
    if (state.video != null) {
      setProgress(db.getVideoProgress(state.video!.videoId));
    }
  }

  setProgress(double progress) {
    if (state.video != null) {
      emit(state.copyWith(progress: progress));
    }
  }

  void showVideoDetails() {
    if (state.video != null) {
      var video = state.video?.copyWith(filtered: false);
      emit(state.copyWith(video: video));
    }
  }
}

@freezed
sealed class VideoInListState with _$VideoInListState {
  @Assert('video == null || offlineVideo == null',
      'cannot provide both video and offline video')
  const factory VideoInListState(
      {@Default(0) double progress,
      Video? video,
      DownloadedVideo? offlineVideo}) = _VideoInListState;
}

import 'dart:async';
import 'dart:collection';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:bloc/bloc.dart';
import 'package:clipious/player/models/sleep_timer.dart';
import 'package:clipious/videos/models/ided_video.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/player/models/media_command.dart';
import 'package:clipious/player/models/media_event.dart';
import 'package:clipious/player/states/interfaces/media_player.dart';
import 'package:clipious/utils.dart';
import 'package:clipious/utils/models/image_object.dart';
import 'package:logging/logging.dart';
import 'package:simple_pip_mode/simple_pip.dart';

import '../../downloads/models/downloaded_video.dart';
import '../../main.dart';
import '../../media_handler.dart';
import '../../settings/states/settings.dart';
import '../../utils/models/pair.dart';
import '../../videos/models/db/progress.dart' as db_progress;
import '../../videos/models/sponsor_segment.dart';
import '../../videos/models/sponsor_segment_types.dart';
import '../../videos/models/video.dart';

part 'player.freezed.dart';

const double targetHeight = 66;
const double miniPlayerThreshold = 300;
const skipToVideoThrottleName = 'skip-to-video';
const double bigPlayerThreshold = 700;
const stepMultiplier = 1.15;

const maxInt = -1 >>> 1;

var log = Logger('MiniPlayerController');

enum PlayerRepeat { noRepeat, repeatAll, repeatOne }

class PlayerCubit extends Cubit<PlayerState> with WidgetsBindingObserver {
  final SettingsCubit settings;
  late final AudioSession audioSession;
  int _sponsorRequestGeneration = 0;
  bool? _requestedPlaying;
  final _timers = <String, Timer>{};

  PlayerCubit(super.initialState, this.settings) {
    onReady();
  }

  void setEvent(MediaEvent event) {
    handleMediaEvent(event);
    mapMediaEventToMediaHandler(event);

    emit(state.copyWith(mediaEvent: event));
  }

  @override
  void didChangeMetrics() {
    var newOrientation = getOrientation();
    if (newOrientation != state.orientation) {
      emit(state.copyWith(orientation: newOrientation));

      onOrientationChange();
    }
  }

  void mapMediaEventToMediaHandler(MediaEvent event) {
    if (!isTv && event.type != MediaEventType.progress) {
      log.fine("Event state: ${event.state}, ${event.type}");
      var playbackState = PlaybackState(
        controls: [
          state.hasQueue ? MediaControl.skipToPrevious : MediaControl.rewind,
          if (state.isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          state.hasQueue ? MediaControl.skipToNext : MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
              MediaState.idle: AudioProcessingState.idle,
              MediaState.loading: AudioProcessingState.loading,
              MediaState.buffering: AudioProcessingState.buffering,
              MediaState.ready: AudioProcessingState.ready,
              MediaState.completed: AudioProcessingState.completed,
              MediaState.playing: AudioProcessingState.ready,
            }[event.state] ??
            AudioProcessingState.ready,
        playing: event.state == MediaState.idle ||
                event.state == MediaState.completed
            ? false
            : state.isPlaying,
        updatePosition: state.position,
        bufferedPosition: state.bufferedPosition,
        speed: state.speed,
        queueIndex: currentIndex,
      );

      mediaHandler.playbackState.add(playbackState);
    }
  }

  int get currentIndex {
    String? currentVideoId = state.currentlyPlaying?.videoId ??
        state.offlineCurrentlyPlaying?.videoId;
    return (state.videos.isNotEmpty ? state.videos : state.offlineVideos)
        .indexWhere((element) => element.videoId == currentVideoId);
  }

  Future<void> onReady() async {
    emit(state.copyWith(
        orientation: getOrientation(),
        forwardStep: settings.state.skipStep,
        rewindStep: settings.state.skipStep));
    // setting up audio session
    audioSession = await AudioSession.instance;
    audioSession.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
    ));
    if (!isTv) {
      WidgetsBinding.instance.addObserver(this);

      audioSession.becomingNoisyEventStream.listen((event) {
        pause();
      });

      mediaHandler = await AudioService.init(
        builder: () => MediaHandler(this),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.github.lamarios.clipious.channel.audio',
          androidNotificationChannelName: 'Video playback',
          androidNotificationOngoing: true,
        ),
      );
      BackButtonInterceptor.add(handleBackButton,
          name: 'miniPlayer', zIndex: 2, ifNotYetIntercepted: true);
    } else if (isTv && state.videos.isNotEmpty) {
      await switchToVideo(state.videos[0]);
      generatePlayQueue();
    }
  }

  void handleMediaEvent(MediaEvent event) {
    switch (event.state) {
      case MediaState.completed:
        if (state.currentlyPlaying != null) {
          saveProgress(state.currentlyPlaying!.lengthSeconds ?? 0);
        }
        // A late completion must not undo a Stop already in progress.
        if (!state.isClosing) playNext();
        _setPlaying(false);
        break;
      default:
        break;
    }

    switch (event.type) {
      case MediaEventType.enteredPip:
        _setPip(true);
        break;
      case MediaEventType.exitedPip:
        _setPip(false);
        break;
      case MediaEventType.progress:
        onProgress(event.value);
        break;
      case MediaEventType.play:
        _setPlaying(_requestedPlaying != false);
        // Source setup can autoplay after a notification or PiP pause request.
        if (_requestedPlaying == false) pause();
        break;
      case MediaEventType.pause:
        _setPlaying(false);
        break;
      case MediaEventType.volumeChanged:
        _setMuted(!event.value);
        break;
      case MediaEventType.aspectRatioChanged:
        emit(state.copyWith(aspectRatio: event.value));
        break;
      default:
        break;
    }
  }

  void _setPip(bool pip) {
    emit(state.copyWith(isPip: pip));
  }

  void _setMuted(bool muted) {
    emit(state.copyWith(muted: muted));
  }

  @override
  close() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    BackButtonInterceptor.removeByName('miniPlayer');
    WidgetsBinding.instance.removeObserver(this);
    super.close();
  }

  bool handleBackButton(bool stopDefaultButtonEvent, RouteInfo info) {
    if (state.fullScreenState == FullScreenState.fullScreen) {
      setFullScreen(FullScreenState.notFullScreen);
      return true;
    } else if (!state.isMini) {
      // we block the backbutton behavior and we make the player small
      showMiniPlayer();
      return true;
    } else {
      return false;
    }
  }

  void selectTab(int index) {
    emit(state.copyWith(selectedFullScreenIndex: index));
  }

  void setAudio(bool? newValue) {
    emit(state.copyWith(isAudio: newValue ?? false));
  }

  void hide() {
    if (isClosed || state.isClosing) return;
    // Background playback must stop before the closing animation can run.
    pause();
    var mediaEvent = MediaEvent(
        state: MediaState.playing,
        type: MediaEventType.miniDisplayChanged,
        value: state.isMini);
    emit(state.copyWith(isClosing: true));
    cancelSleep();
    Future.delayed(
      animationDuration * 1.5,
      () {
        // A video switch clears isClosing; a stale hide must not clear it.
        if (isClosed || !state.isClosing) return;
        emit(state.copyWith(
            isMini: true,
            mediaEvent: mediaEvent,
            top: null,
            height: targetHeight,
            isHidden: true,
            videos: [],
            playedVideos: [],
            currentlyPlaying: null,
            offlineCurrentlyPlaying: null,
            offlineVideos: [],
            isClosing: false));
        setEvent(const MediaEvent(state: MediaState.idle));
      },
    );

    audioSession.setActive(false);
  }

  double get getBottom => state.isHidden ? -targetHeight : 0;

/*
  BaseVideo showVideo() {
    var video = state.videos[state.currentIndex];
    hide();
    return video;
  }
*/

  Future<void> saveProgress(int timeInSeconds) async {
    if (isClosed) return;
    if (state.currentlyPlaying != null) {
      final length = state.currentlyPlaying!.lengthSeconds ?? 0;
      int currentPosition = timeInSeconds.clamp(0, length);
      // saving progress
      var currentProgress = currentPosition / (length == 0 ? 1 : length);
      if (currentProgress >= 0.9) {
        currentProgress =
            1; // we consider a video with 90%+ progress as watched
      }
      var progress = db_progress.Progress.named(
          progress: currentProgress,
          videoId: state.currentlyPlaying!.videoId,
          positionSeconds: currentPosition,
          durationSeconds: length);

      await db.saveProgress(progress);

      if (progress.progress > 0.1) {
        EasyThrottle.throttle('invidious-progress-sync-${progress.videoId}',
            const Duration(minutes: 10), () async {
          if (await service.isLoggedIn()) {
            service.addToUserHistory(progress.videoId);
          }
        });
      }
    }
  }

  void queueVideos(List<Video> videos) {
    final ids = state.videos.map((video) => video.videoId).toSet();
    final additions = videos
        .where((video) => !video.filtered && ids.add(video.videoId))
        .toList();
    if (additions.isEmpty) return;
    emit(state
        .copyWith(offlineVideos: [], videos: [...state.videos, ...additions]));
    generatePlayQueue();
  }

  void showBigPlayer() {
    var mediaEvent = MediaEvent(
        state: MediaState.playing,
        type: MediaEventType.miniDisplayChanged,
        value: state.isMini);

    emit(state.copyWith(
        isMini: false,
        mediaEvent: mediaEvent,
        top: 0,
        isHidden: false,
        isDragging: false,
        dragDistance: 0,
        showMiniPlaceholder: false));
    onOrientationChange();
  }

  void showMiniPlayer() {
    if (state.currentlyPlaying != null ||
        state.offlineCurrentlyPlaying != null) {
      var mediaEvent = MediaEvent(
          state: MediaState.playing,
          type: MediaEventType.miniDisplayChanged,
          value: state.isMini);
      emit(state.copyWith(
        isMini: true,
        mediaEvent: mediaEvent,
        top: null,
        isHidden: false,
        isDragging: false,
        dragDistance: 0,
        showMiniPlaceholder: false,
      ));
    }
  }

  Future<void> onProgress(Duration? position) async {
    var newPosition = position ?? Duration.zero;
    int currentPosition = newPosition.inSeconds;
    await saveProgress(currentPosition);
    log.fine("video progress event");

    emit(state.copyWith(position: newPosition));

    if (state.sponsorSegments.isNotEmpty) {
      final positionInMs = newPosition.inMilliseconds;
      Pair<int> nextSegment = state.sponsorSegments.firstWhere(
          (e) => e.first <= positionInMs && positionInMs < e.last,
          orElse: () => const Pair<int>(-1, -1));

      if (nextSegment.first != -1) {
        log.fine('sponsor skipped');
        emit(state.copyWith(
            mediaEvent: const MediaEvent(
                state: MediaState.playing,
                type: MediaEventType.sponsorSkipped)));
        // The end is exclusive, so landing there cannot trigger another skip.
        seek(Duration(milliseconds: nextSegment.last));
/*
        final ScaffoldMessengerState? scaffold = scaffoldKey.currentState;


        if (scaffold != null) {
          var locals = AppLocalizations.of(scaffold.context)!;
          scaffold.showSnackBar(SnackBar(
            content: Text(locals.sponsorSkipped),
            duration: const Duration(seconds: 1),
          ));
        }
*/

        // log.info('SPONSOR SKIPPED');
      }
    }
  }

  Future<void> _playNextNow() async {
    if (settings.state.playerRepeatMode == PlayerRepeat.repeatOne) {
      seek(Duration.zero);
      play();
    } else if (state.videos.isNotEmpty || state.offlineVideos.isNotEmpty) {
      //moving current video to played list
      String? currentVideoId = state.currentlyPlaying?.videoId ??
          state.offlineCurrentlyPlaying?.videoId;
      if (currentVideoId != null) {
        // state.playedVideos.remove(currentVideoId);
        var newPlayedVideos = List<String>.from(state.playedVideos)
          ..add(currentVideoId);
        emit(state.copyWith(playedVideos: newPlayedVideos));
      }

      if (state.playQueue.isNotEmpty) {
        String toPlay = state.playQueue.removeFirst();
        if (state.videos.isNotEmpty) {
          await switchToVideo(
              state.videos.firstWhere((element) => element.videoId == toPlay));
        } else {
          await switchToOfflineVideo(state.offlineVideos
              .firstWhere((element) => element.videoId == toPlay));
        }
      } else if (settings.state.playerRepeatMode == PlayerRepeat.repeatAll) {
        emit(state.copyWith(playedVideos: [], playQueue: ListQueue.from([])));
        if (state.videos.isNotEmpty) {
          await switchToVideo(state.videos[0]);
        } else {
          await switchToOfflineVideo(state.offlineVideos[0]);
        }
        generatePlayQueue();
      }
    }
  }

  void playNext() {
    EasyThrottle.throttle(
        skipToVideoThrottleName, const Duration(seconds: 1), _playNextNow);
  }

  void playPrevious() {
    EasyThrottle.throttle(skipToVideoThrottleName, const Duration(seconds: 1),
        () async {
      if (state.playedVideos.isNotEmpty) {
        // putting back current video in play queue
        String? currentVideoId = state.currentlyPlaying?.videoId ??
            state.offlineCurrentlyPlaying?.videoId;
        var playQueue = ListQueue<String>.from(state.playQueue);
        if (currentVideoId != null) {
          // state.playQueue.remove(currentVideoId);
          playQueue.addFirst(currentVideoId);
        }

        var playedVideos = List<String>.from(state.playedVideos);
        String toPlay = playedVideos.removeLast();
        if (state.videos.isNotEmpty) {
          await switchToVideo(
              state.videos.firstWhere((element) => element.videoId == toPlay));
        } else {
          await switchToOfflineVideo(state.offlineVideos
              .firstWhere((element) => element.videoId == toPlay));
        }
        emit(state.copyWith(playQueue: playQueue, playedVideos: playedVideos));
      } else {
        // if there's nothing to go back to, we just repeat the last video
        seek(Duration.zero);
        play();
      }
    });
  }

  void _setPlaying(bool playing) {
    emit(state.copyWith(isPlaying: playing));
  }

  Future<void> _playVideos(List<IdedVideo> vids, {Duration? startAt}) async {
    if (vids.isNotEmpty) {
      bool isOffline = vids[0] is DownloadedVideo;

      const mediaEvent = MediaEvent(state: MediaState.loading);

      late List<Video> videos;
      late List<DownloadedVideo> offlineVideos;
      if (isOffline) {
        videos = [];
        offlineVideos = List<DownloadedVideo>.from(vids, growable: true).cast();
      } else {
        offlineVideos = [];
        videos = List<Video>.from(vids, growable: true).cast();
      }

      var selectedFullScreenIndex = 0;
      if (vids.length > 1) {
        selectedFullScreenIndex = 3;
      }
      emit(state.copyWith(
          offlineVideos: offlineVideos,
          videos: videos,
          startAt: startAt,
          mediaEvent: mediaEvent,
          playedVideos: [],
          selectedFullScreenIndex: selectedFullScreenIndex,
          top: 500));

      showBigPlayer();
      if (isOffline) {
        await switchToOfflineVideo(state.offlineVideos[0],
            playing: _requestedPlaying);
      } else {
        await switchToVideo(state.videos[0],
            startAt: startAt, playing: _requestedPlaying);
      }
      generatePlayQueue();
    }
  }

  /// skip to queue video of index
  /// if we're not shuffling, we also rebuild the playnext and played previously queue
  Future<void> skipToVideo(int index) async {
    var listToCheckAgainst =
        state.videos.isNotEmpty ? state.videos : state.offlineVideos;
    if (index < 0 || index >= listToCheckAgainst.length) {
      return;
    }

    if (settings.state.playerShuffleMode) {
      final selectedId = listToCheckAgainst[index].videoId;
      final currentId = state.currentlyPlaying?.videoId ??
          state.offlineCurrentlyPlaying?.videoId;
      if (selectedId == currentId) return;
      emit(state.copyWith(
          playedVideos: [
            ...state.playedVideos,
            if (currentId != null) currentId,
          ],
          playQueue:
              ListQueue.of(state.playQueue.where((id) => id != selectedId))));
    } else {
      List<String> played = [];
      List<String> playNext = [];
      for (int i = 0; i < listToCheckAgainst.length; i++) {
        var v = listToCheckAgainst[i];
        if (i < index) {
          played.add(v.videoId);
        } else if (i > index) {
          playNext.add(v.videoId);
        }
      }
      emit(state.copyWith(
          playedVideos: played, playQueue: ListQueue.from(playNext)));
    }
    await _switchToVideo(listToCheckAgainst[index]);
  }

  /// Switches to a video without changing the queue
  Future<void> _switchToVideo(IdedVideo video,
      {Duration? startAt, bool? playing}) async {
    _requestedPlaying = playing;
    if (state.isClosing) emit(state.copyWith(isClosing: false));
    try {
      // we move the existing video to the stack of played video
      await audioSession.setActive(true);
      bool isOffline = video is DownloadedVideo;
      // we want to switch to audio mode as soon as we can to prevent problems when switching from audio to video or the other way
      if (isOffline) {
        setAudio(video.audioOnly);
      }

      const mediaEvent = MediaEvent(state: MediaState.loading);

      List<Video> videos = List.from(state.videos);
      List<DownloadedVideo> offlineVideos = List.from(state.offlineVideos);
      var currentlyPlaying = state.currentlyPlaying;
      var offlineCurrentlyPlaying = state.offlineCurrentlyPlaying;
      if (isOffline) {
        videos = [];
        currentlyPlaying = null;
      } else {
        offlineVideos = [];
        offlineCurrentlyPlaying = null;
      }

      // List<IdedVideo> toCheck = isOffline ? state.offlineVideos : state.videos;

      emit(state.copyWith(
          mediaEvent: mediaEvent,
          videos: videos,
          currentlyPlaying: currentlyPlaying,
          offlineVideos: offlineVideos,
          offlineCurrentlyPlaying: offlineCurrentlyPlaying));

      late MediaCommand mediaCommand;
      currentlyPlaying = state.currentlyPlaying;
      offlineCurrentlyPlaying = state.offlineCurrentlyPlaying;
      if (!isOffline) {
        late Video v;
        if (video is Video &&
            video.formatStreams != null &&
            video.adaptiveFormats != null) {
          v = video;
        } else {
          v = await service.getVideo(video.videoId);
        }
        currentlyPlaying = v;
        mediaCommand = MediaCommand(MediaCommandType.switchVideo,
            value: SwitchVideoValue(video: v, startAt: startAt));
      } else {
        offlineCurrentlyPlaying = video;
        mediaCommand =
            MediaCommand(MediaCommandType.switchToOfflineVideo, value: video);
      }

      emit(state.copyWith(
          position: Duration.zero,
          forwardStep: settings.state.skipStep,
          rewindStep: settings.state.skipStep,
          mediaCommand: mediaCommand,
          currentlyPlaying: currentlyPlaying,
          offlineCurrentlyPlaying: offlineCurrentlyPlaying));

      await setSponsorBlock();

      if (!isTv) {
        try {
          final item = await getMediaItem(currentIndex);
          mediaHandler.mediaItem.add(item);
        } catch (error, stack) {
          // Artwork/storage failures must not remove a playable queue item.
          log.warning('Could not update playback notification', error, stack);
        }
      }
    } catch (err) {
      if (state.videos.length == 1) {
        // if we can't get video details, we need to stop everything
        log.severe(
            "Couldn't play video  '${video.videoId}', stopping player to avoid app crash");
        hide();
      } else {
        // if we have more than 1 video
        log.severe(
            "Couldn't play video  '${video.videoId}', removing it from the queue");

        removeVideoFromQueue(video.videoId);
        _playNextNow();
      }
    }
  }

  Future<void> playOfflineVideos(List<DownloadedVideo> offlineVids) async {
    _requestedPlaying = null;
    log.fine('Playing ${offlineVids.length} offline videos');
    await _playVideos(offlineVids);
  }

  Future<void> playVideo(List<Video> v,
      {bool? audio, Duration? startAt, bool? playing}) async {
    _requestedPlaying = playing;
    List<Video> videos = v.where((element) => !element.filtered).toList();
    // TODO: find how to do this with auto router
    log.fine('Playing ${videos.length} videos');

    setAudio(audio);

    await _playVideos(videos, startAt: startAt);
  }

  Future<void> switchToOfflineVideo(DownloadedVideo video,
      {bool? playing}) async {
    await _switchToVideo(video, playing: playing);
  }

  Future<void> switchToVideo(Video video,
      {Duration? startAt, bool? playing}) async {
    await _switchToVideo(video, startAt: startAt, playing: playing);
  }

  void togglePlaying() {
    state.isPlaying ? pause() : play();
  }

  void play() {
    _requestedPlaying = true;
    emit(state.copyWith(
        mediaCommand: const MediaCommand(MediaCommandType.play)));
  }

  void pause() {
    _requestedPlaying = false;
    emit(state.copyWith(
        mediaCommand: const MediaCommand(MediaCommandType.pause)));
  }

  void removeVideoFromQueue(String videoId) {
    var videos = List<Video>.from(state.videos);
    var offlineVideos = List<DownloadedVideo>.from(state.offlineVideos);
    var listToUpdate = videos.isNotEmpty ? videos : offlineVideos;
    if (listToUpdate.length == 1) {
      hide();
    } else {
      var playQueue = ListQueue<String>.from(state.playQueue)
        ..removeWhere((element) => element == videoId);
      var playedVideos = List<String>.from(state.playedVideos)
        ..removeWhere((element) => element == videoId);
      listToUpdate.removeWhere((element) => element.videoId == videoId);
      emit(state.copyWith(
          videos: videos,
          offlineVideos: offlineVideos,
          playQueue: playQueue,
          playedVideos: playedVideos));
    }
  }

  void videoDragged(DragUpdateDetails details) {
    // we  change the display mode if there's a big enough drag movement to avoid jittery behavior when dragging slow
    var isMini = state.isMini;
    var mediaEvent = state.mediaEvent;
    if (details.delta.dy.abs() > 3) {
      isMini = details.delta.dy > 0;
      mediaEvent = MediaEvent(
          state: MediaState.playing,
          type: MediaEventType.miniDisplayChanged,
          value: state.isMini);
    }
    var dragDistance = state.dragDistance + details.delta.dy;
    // we're going down, putting threshold high easier to switch to mini player
    emit(state.copyWith(
        isDragging: true,
        showMiniPlaceholder: true,
        top: details.globalPosition.dy - targetHeight / 2,
        dragDistance: dragDistance,
        isMini: isMini,
        mediaEvent: mediaEvent));
  }

  void videoDraggedEnd(DragEndDetails details) {
    bool showMini =
        state.dragDistance.abs() > 200 ? state.isMini : state.dragStartMini;
    // Settle the position and drag state together. A stale absolute top must
    // never survive after the gesture ends or is interrupted by Android.
    if (showMini) {
      showMiniPlayer();
    } else {
      showBigPlayer();
    }
  }

  void videoDragCancelled() {
    if (isClosed || !state.isDragging || state.isClosing) return;
    if (state.dragStartMini) {
      showMiniPlayer();
    } else {
      showBigPlayer();
    }
  }

  void videoDragStarted(DragStartDetails details) {
    emit(state.copyWith(dragDistance: 0, dragStartMini: state.isMini));
  }

  bool isVideoInQueue(Video video) {
    return state.videos
            .indexWhere((element) => element.videoId == video.videoId) >=
        0;
  }

  void onQueueReorder(int oldItemIndex, int newItemIndex) {
    var videos = List<Video>.from(state.videos);
    var offlineVideos = List<DownloadedVideo>.from(state.offlineVideos);
    var listToUpdate = videos.isNotEmpty ? videos : offlineVideos;
    if (oldItemIndex < 0 ||
        oldItemIndex >= listToUpdate.length ||
        newItemIndex < 0 ||
        newItemIndex > listToUpdate.length) {
      return;
    }
    // Flutter reports the insertion slot before removing the dragged item.
    if (oldItemIndex < newItemIndex) {
      newItemIndex--;
    }
    if (oldItemIndex == newItemIndex) {
      return;
    }
    var movedItem = listToUpdate.removeAt(oldItemIndex);
    listToUpdate.insert(newItemIndex, movedItem);
    var playedVideos = state.playedVideos;
    final currentId = state.currentlyPlaying?.videoId ??
        state.offlineCurrentlyPlaying?.videoId;
    final current =
        listToUpdate.indexWhere((video) => video.videoId == currentId);
    if (!settings.state.playerShuffleMode && current >= 0) {
      // Queue order determines previous/next playback outside shuffle mode.
      playedVideos =
          listToUpdate.take(current).map((video) => video.videoId).toList();
    }
    emit(state.copyWith(
        playedVideos: playedVideos,
        videos: videos,
        offlineVideos: offlineVideos));
    generatePlayQueue();
  }

  void playVideoNext(Video video) {
    if (state.videos.isEmpty) {
      playVideo([video]);
    } else {
      final videos = state.videos.any((item) => item.videoId == video.videoId)
          ? state.videos
          : [...state.videos, video];
      var playQueue = ListQueue<String>.from(state.playQueue)
        ..removeWhere((id) => id == video.videoId)
        ..addFirst(video.videoId);
      emit(state.copyWith(videos: videos, playQueue: playQueue));
    }
  }

  Future<void> setSponsorBlock() async {
    final request = ++_sponsorRequestGeneration;
    final videoId = state.currentlyPlaying?.videoId ??
        state.offlineCurrentlyPlaying?.videoId;
    final types = SponsorSegmentType.values
        .where((e) => db.getSettings(e.settingsName())?.value == 'true')
        .toList();
    List<SponsorSegment> segments = [];
    if (videoId != null && types.isNotEmpty) {
      try {
        segments = await service
            .getSponsorSegments(videoId, types)
            .timeout(const Duration(seconds: 3), onTimeout: () => []);
      } catch (error) {
        // Optional community metadata must never prevent playback.
        log.fine('SponsorBlock unavailable', error);
      }
    }
    if (!isClosed &&
        request == _sponsorRequestGeneration &&
        (state.currentlyPlaying?.videoId ??
                state.offlineCurrentlyPlaying?.videoId) ==
            videoId) {
      emit(state.copyWith(sponsorSegments: _sponsorIntervals(segments, types)));
    }
  }

  List<Pair<int>> _sponsorIntervals(
      List<SponsorSegment> segments, List<SponsorSegmentType> types) {
    final length = state.currentlyPlaying?.lengthSeconds ??
        state.offlineCurrentlyPlaying?.lengthSeconds ??
        0;
    final intervals = <Pair<int>>[];
    for (final segment in segments) {
      if (segment.actionType != 'skip' ||
          !types.contains(segment.category) ||
          segment.segment.length != 2) {
        continue;
      }
      final start = segment.segment[0];
      final end = segment.segment[1];
      if (!start.isFinite ||
          !end.isFinite ||
          start < 0 ||
          end <= start ||
          (length > 0 && start >= length)) {
        continue;
      }
      final boundedEnd = length > 0 ? end.clamp(0, length) : end;
      final startMs = start * 1000;
      final endMs = boundedEnd * 1000;
      if (!startMs.isFinite || !endMs.isFinite || endMs > maxInt) continue;
      final interval = Pair(startMs.round(), endMs.round());
      if (interval.last > interval.first) intervals.add(interval);
    }
    intervals.sort((a, b) => a.first.compareTo(b.first));
    final merged = <Pair<int>>[];
    for (final interval in intervals) {
      if (merged.isEmpty || interval.first > merged.last.last) {
        merged.add(interval);
      } else if (interval.last > merged.last.last) {
        merged[merged.length - 1] = Pair(merged.last.first, interval.last);
      }
    }
    return merged;
  }

  void seek(Duration duration) {
    if (duration.inSeconds < 0) {
      duration = Duration.zero;
    }

    var videoLength = state.currentlyPlaying?.lengthSeconds ??
        state.offlineCurrentlyPlaying?.lengthSeconds ??
        1;
    if (duration.inSeconds > (videoLength)) {
      duration = Duration(seconds: videoLength);
    }

    emit(state.copyWith(
        position: duration,
        mediaCommand: MediaCommand(MediaCommandType.seek, value: duration)));
  }

  void fastForward() {
    var newPosition = state.position + Duration(seconds: state.forwardStep);
    seek(newPosition);
    log.info('fast forward $newPosition - step: ${state.forwardStep}');
    emit(state.copyWith(
      totalFastForward: state.totalFastForward + state.forwardStep,
      forwardStep: (state.forwardStep *
              (settings.state.skipExponentially ? stepMultiplier : 1))
          .floor(),
    ));
    _debounce('fast-forward-step', const Duration(seconds: 1), () {
      emit(state.copyWith(
        forwardStep: settings.state.skipStep,
        totalFastForward: 0,
      ));
    });
  }

  void rewind() {
    seek(state.position - Duration(seconds: state.rewindStep));
    emit(state.copyWith(
      totalRewind: state.totalRewind + state.rewindStep,
      rewindStep: (state.rewindStep *
              (settings.state.skipExponentially ? stepMultiplier : 1))
          .floor(),
    ));
    _debounce('fast-rewind-step', const Duration(seconds: 1), () {
      emit(state.copyWith(
        rewindStep: settings.state.skipStep,
        totalRewind: 0,
      ));
    });
  }

  Future<MediaItem?> getMediaItem(int index) async {
    if (state.videos.isNotEmpty) {
      var e = state.videos[index];
      return MediaItem(
          id: e.videoId,
          title: e.title ?? '',
          artist: e.author,
          duration: Duration(seconds: e.lengthSeconds ?? 1),
          album: '',
          artUri: Uri.parse(
              ImageObject.getBestThumbnail(e.videoThumbnails)?.url ?? ''));
    } else if (state.offlineVideos.isNotEmpty) {
      var e = state.offlineVideos[index];
      var path = await e.thumbnailPath;
      return MediaItem(
          id: e.videoId,
          title: e.title,
          artist: e.author,
          duration: Duration(seconds: e.lengthSeconds),
          album: '',
          artUri: Uri.file(path));
    }
    return null;
  }

  void setSpeed(double d) {
    emit(state.copyWith(
        mediaCommand: MediaCommand(MediaCommandType.speed, value: d)));
  }

  void setFullScreen(FullScreenState fsState) {
    // emit(state.copyWith(mediaCommand: MediaCommand(MediaCommandType.fullScreen, value: fsState)));
    emit(state.copyWith(
        fullScreenState: fsState,
        mediaCommand: MediaCommand(fsState == FullScreenState.notFullScreen
            ? MediaCommandType.exitFullScreen
            : MediaCommandType.enterFullScreen),
        mediaEvent: MediaEvent(
            state: state.mediaEvent.state,
            type: MediaEventType.fullScreenChanged,
            value: fsState)));

    switch (fsState) {
      case FullScreenState.fullScreen:
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
        // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.black));
        if (settings.state.forceLandscapeFullScreen && state.aspectRatio > 1) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
          ]);
        }
        break;
      default:
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: SystemUiOverlay.values);
        SystemChrome.setPreferredOrientations([]);
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle());
    }
  }

  void enterPip() {
    setFullScreen(FullScreenState.fullScreen);
    setEvent(const MediaEvent(
        state: MediaState.playing, type: MediaEventType.enteredPip));
    SimplePip(
      onPipExited: () {
        setEvent(const MediaEvent(
            state: MediaState.playing, type: MediaEventType.exitedPip));
        setFullScreen(FullScreenState.notFullScreen);
      },
    ).enterPipMode();
  }

  void setMuted(bool muted) {
    emit(state.copyWith(
        mediaCommand: MediaCommand(
            muted ? MediaCommandType.mute : MediaCommandType.unmute)));
  }

  Duration get duration => Duration(
      seconds: (state.currentlyPlaying?.lengthSeconds ??
          state.offlineCurrentlyPlaying?.lengthSeconds ??
          1));

  double get progress {
    final length = duration.inMilliseconds;
    return length <= 0
        ? 0
        : (state.position.inMilliseconds / length).clamp(0.0, 1.0);
  }

  void switchAudio(bool value) {
    if (state.currentlyPlaying != null &&
        !state.isClosing &&
        state.isAudio != value) {
      // The replacement decoder reads its starting position when it mounts.
      videoDragCancelled();
      emit(state.copyWith(isAudio: value, startAt: state.position));
    }
  }

  void generatePlayQueue() {
    final played = state.playedVideos.toSet();
    final currentId = state.currentlyPlaying?.videoId ??
        state.offlineCurrentlyPlaying?.videoId;
    if (currentId != null) played.add(currentId);
    List<String> videos =
        (state.videos.isNotEmpty ? state.videos : state.offlineVideos)
            .where((element) => !played.contains(element.videoId))
            .map((e) => e.videoId)
            .toList();

    // if we're in shuffle mode, we shuffle the collection
    if (settings.state.playerShuffleMode) {
      videos.shuffle();
    }

    ListQueue<String> playQueue = ListQueue.from(videos);
    emit(state.copyWith(playQueue: playQueue));
  }

  void onOrientationChange() {
    if (getDeviceType() == DeviceType.phone &&
        (state.orientation == Orientation.landscape) &&
        !state.isMini &&
        settings.state.fullscreenOnRotate) {
      setFullScreen(FullScreenState.fullScreen);
    }
  }

  void sleep(SleepTimer sleepTimer) {
    emit(state.copyWith(hasTimer: true));

    _debounce(
      'video-sleep-timer',
      sleepTimer.duration,
      () {
        emit(state.copyWith(hasTimer: false));
        pause();
        if (sleepTimer.stopVideo && !isClosed) {
          hide();
        }
      },
    );
  }

  void cancelSleep() {
    emit(state.copyWith(hasTimer: false));
    _timers.remove('video-sleep-timer')?.cancel();
  }

  void _debounce(String name, Duration delay, VoidCallback callback) {
    if (isClosed) return;
    _timers.remove(name)?.cancel();
    _timers[name] = Timer(delay, () {
      _timers.remove(name);
      if (!isClosed) callback();
    });
  }
}

@freezed
sealed class PlayerState with _$PlayerState {
  const factory PlayerState(
      {
      // player display properties
      @Default(true) bool isMini,
      @Default(false) bool hasTimer,
      double? top,
      @Default(false) bool isDragging,
      @Default(0) int selectedFullScreenIndex,
      @Default(true) bool isHidden,
      @Default(false) bool isClosing,
      @Default(0) double dragDistance,
      @Default(false) bool showMiniPlaceholder,
      @Default(true) bool dragStartMini,
      @Default(targetHeight) double height,
      @Default(FullScreenState.notFullScreen) FullScreenState fullScreenState,
      @Default(false) bool muted,
      @Default(16 / 9) double aspectRatio,

      // videos to play
      Video? currentlyPlaying,
      DownloadedVideo? offlineCurrentlyPlaying,
      @Default([]) List<Video> videos,
      @Default([]) List<DownloadedVideo> offlineVideos,

      // playlist controls
      @Default([]) List<String> playedVideos,
      required ListQueue<String> playQueue,
      @Default(false) bool isAudio,

      // playing video data
      @Default(false) bool isPip,
      @Default(Offset.zero) Offset offset,
      Duration? startAt,
      @Default(Duration.zero) Duration position,
      @Default(Duration.zero) Duration bufferedPosition,
      @Default(false) bool isPlaying,
      @Default(1.0) double speed,

      // events
      // command we send down the stack, namely video / audio player
      MediaCommand? mediaCommand,

      // events we receive from bottom of stack
      @Default(MediaEvent(state: MediaState.idle)) MediaEvent mediaEvent,

      // sponsor block variables
      @Default([]) List<Pair<int>> sponsorSegments,
      @Default(Pair(0, 0)) Pair<int> nextSegment,

      // step in seconds when fast forawrd or fast rewind
      @Default(defaultStep) int forwardStep,
      @Default(defaultStep) rewindStep,
      @Default(0) int totalFastForward,
      @Default(0) totalRewind,
      @Default(Orientation.portrait) Orientation orientation}) = _PlayerState;

  bool get hasVideo =>
      currentlyPlaying != null || offlineCurrentlyPlaying != null;

  bool get hasQueue => offlineVideos.length > 1 || videos.length > 1;

  const PlayerState._();

//
  static PlayerState init(List<Video>? videos) {
    return PlayerState(videos: videos ?? [], playQueue: ListQueue.from([]));
  }
}

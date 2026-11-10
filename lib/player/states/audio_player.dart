import 'package:easy_debounce/easy_throttle.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/downloads/models/downloaded_video.dart';
import 'package:clipious/extensions.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/player/states/interfaces/media_player.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../../settings/states/settings.dart';
import '../../videos/models/adaptive_format.dart';
import '../media_source.dart';
import '../models/media_event.dart';

part 'audio_player.freezed.dart';

Logger log = Logger('AudioPlayerController');

class AudioPlayerCubit extends MediaPlayerCubit<AudioPlayerState> {
  AudioPlayer? audioPlayer;
  final SettingsCubit settings;

  AudioPlayerCubit(super.initialState, super.player, this.settings) {
    onInit();
  }

  @override
  close() async {
    disposeControllers();
    super.close();
  }

  void onInit() {
    initPlayer();
    playVideo(state.offlineVideo != null);
  }

  @override
  void disposeControllers() {
    audioPlayer?.dispose();
  }

  void initPlayer() {
    if (audioPlayer == null) {
      audioPlayer = AudioPlayer();
      audioPlayer?.playerStateStream.listen(onStateStreamChange,
          onError: (e, st) {
        return player.setEvent(const MediaEvent(state: MediaState.error));
      });
      audioPlayer?.positionStream.listen(onPositionChanged);
      audioPlayer?.durationStream.listen(onDurationChanged);
      audioPlayer?.bufferedPositionStream.listen(onBufferChanged);
    }
  }

  void onStateStreamChange(PlayerState state) {
    log.fine('Player state event $state');
    switch (state.processingState) {
      case ProcessingState.idle:
        // looks like this is causing issues with the player control notification
        // MiniPlayerController.to()?.eventStream.add(MediaEvent(state: MediaState.idle));
        break;
      case ProcessingState.loading:
        player.setEvent(const MediaEvent(state: MediaState.loading));
        break;
      case ProcessingState.buffering:
        player.setEvent(const MediaEvent(state: MediaState.buffering));
        break;
      case ProcessingState.ready:
        player.setEvent(const MediaEvent(state: MediaState.ready));
        // Audio focus changes can pause/resume the native decoder without a
        // UI command. Keep transport controls and notifications in sync.
        player.setEvent(MediaEvent(
            state: MediaState.playing,
            type: playing ? MediaEventType.play : MediaEventType.pause));
        break;
      case ProcessingState.completed:
        player.setEvent(const MediaEvent(state: MediaState.completed));
        break;
    }
  }

  Future<void> onDurationChanged(Duration? duration) async {
    emit(state.copyWith(loading: false));
    if (!isClosed) emit(state);
    player.setEvent(MediaEvent(
        state: MediaState.playing,
        type: MediaEventType.durationChanged,
        value: duration ?? const Duration(seconds: 1)));
  }

  void onPositionChanged(Duration position) {
    EasyThrottle.throttle('audio-progress', const Duration(seconds: 1), () {
      emit(state.copyWith(audioPosition: position));
      player.setEvent(MediaEvent(
          state: MediaState.playing,
          type: MediaEventType.progress,
          value: position));
    });
  }

  @override
  playVideo(bool offline, {Duration? startAt}) async {
    if (!player.state.isAudio) {
      return;
    }
    if (state.video != null || state.offlineVideo != null) {
      // disposeControllers();
      initPlayer();
      var audioLength = Duration(
          seconds: offline
              ? state.offlineVideo!.lengthSeconds
              : (state.video!.lengthSeconds ?? 0));
      emit(state.copyWith(
          audioPosition: Duration.zero,
          audioLength: audioLength,
          loading: true));
      player.setEvent(const MediaEvent(state: MediaState.loading));
      try {
        AudioSource? source;
        final server = await db.getCurrentlySelectedServer();

        if (!offline) {
          assert(state.video!.formatStreams != null);
          final proxy = service.useProxy();
          final combined = (state.video!.formatStreams ?? [])
              .where((stream) => !stream.isLegacyHd720)
              .toList()
              .reversed
              .map((stream) => stream.url);
          final adaptive = (state.video?.adaptiveFormats ?? <AdaptiveFormat>[])
              .where((format) => format.type.startsWith('audio/'))
              .sortByReversed(
                  (format) => int.tryParse(format.bitrate ?? '') ?? 0)
              .map((format) => format.url);
          // Keep the combined proxy source preference, but audio-only
          // responses must use the same instance route as video playback.
          final candidates =
              proxy ? [...combined, ...adaptive] : [...adaptive, ...combined];
          for (final candidate in candidates) {
            final parsed = parseMediaUrl(candidate);
            if (parsed == null) continue;
            final url =
                validatedMediaUrl(proxyMediaUrl(parsed, server, proxy), server);
            if (url == null) continue;
            if (startAt == null && !proxy) {
              final resumed = db
                  .getVideoPlaybackProgress(state.video!.videoId)
                  .resumePosition(durationSeconds: state.video!.lengthSeconds);
              if (resumed != Duration.zero) startAt = resumed;
            }
            emit(state);

            source = AudioSource.uri(Uri.parse(url),
                headers: mediaHeaders(server, url));
            break;
          }
        } else {
          String path = await state.offlineVideo!.effectivePath;
          source = AudioSource.file(path);
        }

        if (source == null) {
          throw Error();
        }

        await audioPlayer?.setAudioSource(source, initialPosition: startAt);

        // Source initialization may briefly report zero before its initial
        // seek. Publish the admitted position before any play/rate event:
        // MediaSession extrapolates progress from those events.
        final position = audioPlayer?.position ?? Duration.zero;
        emit(state.copyWith(audioPosition: position));
        player.setEvent(MediaEvent<Duration>(
            state: MediaState.ready,
            type: MediaEventType.progress,
            value: position));

        play();
        // TODO: make this less duplicated between videos and audio
        double speed = 1.0;
        if (settings.state.rememberPlayBackSpeed) {
          speed = settings.state.lastSpeed;

          log.fine("Setting playback speed to $speed");
          audioPlayer?.setSpeed(speed);
        }
      } catch (e) {
        log.severe("Couldn't play video", e);
        player.setEvent(const MediaEvent(state: MediaState.error));
        if (!isClosed) {
          emit(state.copyWith(error: e.toString(), loading: false));
        }
      }
    }
    super.playVideo(offline);
  }

  @override
  double getAspectRatio() {
    return 16 / 9;
  }

  @override
  void switchToOfflineVideo(DownloadedVideo v) {
    emit(state.copyWith(video: null, offlineVideo: v));
    playVideo(true, startAt: player.state.startAt);
  }

  @override
  void switchVideo(Video video, {Duration? startAt}) async {
    emit(state.copyWith(video: video, offlineVideo: null));
    playVideo(false, startAt: startAt);
  }

  @override
  void togglePlaying() {
    var state = this.state.copyWith();
    playing ? play() : pause();
    emit(state);
  }

  void onScrubbed(double value) {
    Duration seekTo = Duration(milliseconds: value.toInt());
    seek(seekTo);
    emit(state.copyWith(audioPosition: seekTo));
  }

  void onScrubDrag(double value) {
    Duration seekTo = Duration(milliseconds: value.toInt());
    emit(state.copyWith(audioPosition: seekTo));
  }

  @override
  void toggleControls(bool visible) {
    emit(state.copyWith(disableControls: !visible));
  }

  @override
  bool isPlaying() {
    return playing;
  }

  @override
  void play() {
    audioPlayer?.play();
    player.setEvent(
        const MediaEvent(state: MediaState.playing, type: MediaEventType.play));
  }

  @override
  void seek(Duration position) {
    audioPlayer?.seek(position);
    player.setEvent(
        const MediaEvent(state: MediaState.playing, type: MediaEventType.seek));
    player.setEvent(MediaEvent(
        state: MediaState.playing,
        type: MediaEventType.progress,
        value: position));
  }

  @override
  void pause() {
    audioPlayer?.pause();
    player.setEvent(const MediaEvent(
        state: MediaState.playing, type: MediaEventType.pause));
  }

  @override
  Duration? bufferedPosition() {
    return audioPlayer?.bufferedPosition;
  }

  @override
  Duration position() {
    return state.audioPosition;
  }

  @override
  double? speed() {
    return 1;
  }

  @override
  List<String> getVideoTracks() {
    return [];
  }

  @override
  List<String> getAudioTracks() {
    return [];
  }

  @override
  List<String> getSubtitles() {
    return [];
  }

  @override
  int selectedAudioTrack() {
    return 0;
  }

  @override
  int selectedSubtitle() {
    return 0;
  }

  @override
  int selectedVideoTrack() {
    return 0;
  }

  @override
  void selectAudioTrack(int index) {}

  @override
  selectSubtitle(int index) {}

  @override
  selectVideoTrack(int index) {}

  bool supportsPip() {
    return false;
  }

  void enterPip() {}

  @override
  bool isMuted() {
    return (audioPlayer?.volume ?? 0) == 0;
  }

  @override
  void toggleVolume(bool soundOn) {
    audioPlayer?.setVolume(soundOn ? 1 : 0);
  }

  @override
  void setSpeed(double d) {
    audioPlayer?.setSpeed(d);
    settings.setLastSpeed(d);
  }

  @override
  double getSpeed() {
    return audioPlayer?.speed ?? 1;
  }

  @override
  bool hasDashToggle() {
    return false;
  }

  @override
  void toggleDash() {
    // TODO: implement toggleDash
  }

  @override
  bool isUsingDash() {
    // TODO: implement isUsingDash
    throw UnimplementedError();
  }

  @override
  Duration duration() {
    return audioPlayer?.duration ?? const Duration(milliseconds: 1);
  }

  void onBufferChanged(Duration event) {
    EasyThrottle.throttle('audio-buffering', const Duration(seconds: 1), () {
      player.setEvent(MediaEvent(
          state: MediaState.playing,
          type: MediaEventType.bufferChanged,
          value: event));
    });
  }

  bool get playing => audioPlayer?.playing ?? false;
}

@freezed
sealed class AudioPlayerState extends MediaPlayerState with _$AudioPlayerState {
  const factory AudioPlayerState({
    @Default(Duration(milliseconds: 1)) Duration audioLength,
    @Default(Duration.zero) Duration audioPosition,
    @Default(0) int previousSponsorCheck,
    Video? video,
    DownloadedVideo? offlineVideo,
    bool? playNow,
    bool? disableControls,
    @Default(false) bool loading,
    String? error,
  }) = _AudioPlayerState;

  double get progress =>
      audioPosition.inMilliseconds / audioLength.inMilliseconds;

  const AudioPlayerState._();
}

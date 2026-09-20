import 'package:auto_route/annotations.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/player/views/components/video_player.dart';
import 'package:clipious/player/views/tv/components/recommended_videos.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/utils.dart';
import 'package:clipious/utils/views/tv/components/tv_overscan.dart';

import '../../../../main.dart';

@RoutePage()
class TvPlayerScreen extends StatefulWidget {
  final List<Video> videos;

  const TvPlayerScreen({super.key, required this.videos});

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  /// Focus node of the player controls overlay, used to give focus back to the
  /// video when the user leaves the recommended videos.
  final FocusNode controlsFocusNode =
      FocusNode(debugLabel: 'tv-player-controls');

  /// Whether the recommended videos panel is currently revealed.
  bool browsing = false;

  @override
  void dispose() {
    controlsFocusNode.dispose();
    super.dispose();
  }

  void enterBrowse() {
    if (browsing) {
      return;
    }
    setState(() => browsing = true);
  }

  void exitBrowse() {
    if (!browsing) {
      return;
    }
    setState(() => browsing = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controlsFocusNode.requestFocus();
      }
    });
  }

  void selectRecommended(BuildContext context, Video video) {
    context.read<PlayerCubit>().switchToVideo(video);
    exitBrowse();
  }

  List<Video> recommendationsFor(Video? video) =>
      filteredVideos(video?.recommendedVideos ?? []);

  @override
  Widget build(BuildContext context) {
    var settings = context.read<SettingsCubit>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              PlayerCubit(PlayerState.init(widget.videos), settings),
        )
      ],
      child: Theme(
        data: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
        child: PopScope(
          canPop: !browsing,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && browsing) {
              exitBrowse();
            }
          },
          child: Scaffold(
            body: BlocBuilder<PlayerCubit, PlayerState>(
              builder: (context, state) {
                final recommended = recommendationsFor(state.currentlyPlaying);
                final player = context.read<PlayerCubit>();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double fullHeight = constraints.maxHeight;
                    final double videoHeight =
                        browsing ? fullHeight * 0.6 : fullHeight;
                    final double aspectRatio =
                        state.aspectRatio > 0 ? state.aspectRatio : 16 / 9;
                    final double videoWidth = (videoHeight * aspectRatio)
                        .clamp(0.0, constraints.maxWidth);

                    return Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyUpEvent || !browsing) {
                          return KeyEventResult.ignored;
                        }
                        // While browsing, the player controls overlay does not
                        // have focus, so handle the essential media keys here.
                        switch (event.logicalKey) {
                          case LogicalKeyboardKey.goBack:
                            exitBrowse();
                            return KeyEventResult.handled;
                          case LogicalKeyboardKey.mediaPlay:
                            player.play();
                            return KeyEventResult.handled;
                          case LogicalKeyboardKey.mediaPause:
                            player.pause();
                            return KeyEventResult.handled;
                          case LogicalKeyboardKey.mediaPlayPause:
                            player.togglePlaying();
                            return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedContainer(
                            duration: animationDuration,
                            curve: animationCurve,
                            height: videoHeight,
                            color: Colors.black,
                            child: state.hasVideo
                                ? Center(
                                    child: SizedBox(
                                      width: videoWidth,
                                      height: videoHeight,
                                      child: VideoPlayer(
                                        video: state.currentlyPlaying,
                                        miniPlayer: false,
                                        playNow: true,
                                        disableControls: true,
                                        controlsFocusNode: controlsFocusNode,
                                        onEnterRecommendations: enterBrowse,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: animationDuration,
                              child: browsing
                                  ? Container(
                                      color: darkColorScheme.surface,
                                      child: TvOverscan(
                                        child: TvPlayerRecommendedVideos(
                                          videos: recommended,
                                          onSelect: selectRecommended,
                                          onExitUp: exitBrowse,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

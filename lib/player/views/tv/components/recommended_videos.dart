import 'package:clipious/globals.dart';
import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:clipious/utils.dart';
import 'package:clipious/utils/models/image_object.dart';
import 'package:clipious/utils/views/components/thumbnail.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:clipious/videos/views/components/video_metrics.dart';
import 'package:clipious/videos/views/components/video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Panel shown below the video when the user navigates down in the TV player.
///
/// It behaves like YouTube TV: the video shrinks to the top of the screen and
/// this panel fills the remaining space with a vertical list of recommended
/// videos.
class TvPlayerRecommendedVideos extends StatelessWidget {
  final List<Video> videos;
  final void Function(BuildContext context, Video video) onSelect;
  final VoidCallback onExitUp;

  const TvPlayerRecommendedVideos({
    super.key,
    required this.videos,
    required this.onSelect,
    required this.onExitUp,
  });

  @override
  Widget build(BuildContext context) {
    AppLocalizations locals = AppLocalizations.of(context)!;
    TextTheme textTheme = Theme.of(context).textTheme;

    return FocusScope(
      autofocus: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
            child: Text(
              locals.recommended,
              style: textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: videos.length,
              itemBuilder: (context, index) => TvPlayerRecommendedVideoItem(
                video: videos[index],
                isFirst: index == 0,
                onSelect: onSelect,
                onExitUp: onExitUp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TvPlayerRecommendedVideoItem extends StatelessWidget {
  final Video video;
  final bool isFirst;
  final void Function(BuildContext context, Video video) onSelect;
  final VoidCallback onExitUp;

  const TvPlayerRecommendedVideoItem({
    super.key,
    required this.video,
    required this.isFirst,
    required this.onSelect,
    required this.onExitUp,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;

    return Focus(
      autofocus: isFirst,
      onKeyEvent: (node, event) {
        // Handle up on key down: directional focus traversal also reacts to key
        // down, so it has to be stopped here to leave the recommended videos.
        if (event is KeyDownEvent &&
            isFirst &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          onExitUp();
          return KeyEventResult.handled;
        }
        if (event is KeyUpEvent &&
            isOk(event.logicalKey, physicalKeyboardKey: event.physicalKey)) {
          onSelect(context, video);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        bool hasFocus = Focus.of(ctx).hasFocus;
        return AnimatedContainer(
          duration: animationDuration,
          curve: animationCurve,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasFocus ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: VideoThumbnailView(
                  videoId: video.videoId,
                  thumbnails: video.thumbnails,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        video.title ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium
                            ?.copyWith(color: colors.primary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Thumbnail(
                            thumbnails:
                                ImageObject.getThumbnailUrlsByPreferredOrder(
                                    video.authorThumbnails),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: colors.secondaryContainer,
                            ),
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                video.author ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: colors.secondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      VideoMetrics(
                        video: video,
                        style: textTheme.bodySmall,
                        showDuration: false,
                        iconSize: 13,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

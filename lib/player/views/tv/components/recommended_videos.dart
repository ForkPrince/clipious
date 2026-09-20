import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:clipious/utils/models/paginated_list.dart';
import 'package:clipious/utils/views/tv/components/tv_horizontal_item_list.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shelf shown below the video when the user navigates down in the TV player.
///
/// It behaves like YouTube TV: the video shrinks to the top of the screen and
/// this shelf fills the remaining space with a horizontal list of recommended
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

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        // Handle up on key down: directional focus traversal also reacts to key
        // down, so it has to be stopped here to leave the recommended videos.
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          onExitUp();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double listHeight =
              (constraints.maxHeight - 46).clamp(120.0, 300.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                child: Text(
                  locals.recommended,
                  style: textTheme.titleLarge,
                ),
              ),
              TvHorizontalVideoList(
                height: listHeight,
                onSelect: onSelect,
                paginatedVideoList: FixedItemList<Video>(videos),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:clipious/videos/models/video.dart';
import 'package:clipious/videos/states/hidden_videos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/utils.dart';
import 'package:clipious/videos/views/components/add_to_playlist_button.dart';
import 'package:clipious/videos/views/components/download_modal_sheet.dart';

import '../../../main.dart';
import 'add_to_queue_button.dart';

const _sheetActionWidth = 84.0;

class VideoModalSheet extends StatelessWidget {
  final Video video;

  const VideoModalSheet({super.key, required this.video});

  static void showVideoModalSheet(BuildContext context, Video video) {
    showSafeModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext context) {
          return SafeArea(
            child: VideoModalSheet(
              video: video,
            ),
          );
        });
  }

  void playNext(BuildContext context) {
    var player = context.read<PlayerCubit>();
    var locals = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    player.playVideoNext(video);

    final ScaffoldMessengerState? scaffold = scaffoldKey.currentState;
    scaffold?.showSnackBar(SnackBar(
      content: Text(locals.playNextAddedToQueue),
      duration: const Duration(seconds: 1),
    ));
  }

  void addToQueue(BuildContext context) {
    var player = context.read<PlayerCubit>();
    var locals = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    player.queueVideos([video]);

    final ScaffoldMessengerState? scaffold = scaffoldKey.currentState;
    scaffold?.showSnackBar(SnackBar(
      content: Text(locals.videoAddedToQueue),
      duration: const Duration(seconds: 1),
    ));
  }

  void downloadVideo(BuildContext context) {
    Navigator.of(context).pop();
    DownloadModalSheet.showVideoModalSheet(context, video);
  }

  void _showSharingSheet(BuildContext context) {
    Navigator.of(context).pop();
    showSharingSheet(context, video);
  }

  void hideVideo(BuildContext context) async {
    Navigator.of(context).pop();
    var ok = await HiddenVideosCubit.instance.hideVideo(video.videoId);
    final ScaffoldMessengerState? scaffold = scaffoldKey.currentState;
    scaffold?.showSnackBar(SnackBar(
      content: Text(ok ? 'Video hidden' : 'Could not hide video'),
      duration: const Duration(seconds: 1),
    ));
  }

  void unhideVideo(BuildContext context) async {
    Navigator.of(context).pop();
    var ok = await HiddenVideosCubit.instance.unhideVideo(video.videoId);
    final ScaffoldMessengerState? scaffold = scaffoldKey.currentState;
    scaffold?.showSnackBar(SnackBar(
      content: Text(ok ? 'Video unhidden' : 'Could not unhide video'),
      duration: const Duration(seconds: 1),
    ));
  }

  Widget _action(Widget button, String label) {
    return SizedBox(
      width: _sheetActionWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis)
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var locals = AppLocalizations.of(context)!;
    HiddenVideosCubit.instance.ensureLoaded();
    final hiddenFuture = service.supportsHidden();
    return FractionallySizedBox(
      widthFactor: 1,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: _sheetActionWidth,
                  child: AddToPlayListButton(
                    videoId: video.videoId,
                    type: AddToPlayListButtonType.modalSheet,
                    afterAdd: () => Navigator.pop(context),
                  ),
                ),
                _action(
                    IconButton.filledTonal(
                        onPressed:
                            AddToQueueButton.canAddToQueue(context, [video])
                                ? () => addToQueue(context)
                                : null,
                        icon: const Icon(Icons.playlist_play)),
                    locals.addToQueueList),
                _action(
                    IconButton.filledTonal(
                        onPressed: () => playNext(context),
                        icon: const Icon(Icons.play_arrow)),
                    locals.playNext),
                _action(
                    IconButton.filledTonal(
                        onPressed: () => downloadVideo(context),
                        icon: const Icon(Icons.download)),
                    locals.download),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _action(
                    IconButton.filledTonal(
                        onPressed: () => _showSharingSheet(context),
                        icon: const Icon(Icons.share)),
                    locals.share),
                FutureBuilder<bool>(
                  future: hiddenFuture,
                  builder: (context, snapshot) {
                    if (snapshot.data != true) {
                      return const SizedBox.shrink();
                    }
                    return BlocBuilder<HiddenVideosCubit, HiddenVideosState>(
                      bloc: HiddenVideosCubit.instance,
                      builder: (context, hiddenState) {
                        var hidden =
                            hiddenState.hiddenIds.contains(video.videoId);
                        return _action(
                            IconButton.filledTonal(
                                onPressed: () => hidden
                                    ? unhideVideo(context)
                                    : hideVideo(context),
                                icon: Icon(hidden
                                    ? Icons.visibility
                                    : Icons.visibility_off)),
                            hidden ? 'Unhide' : 'Hide');
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class CommentVoiceReplyView extends StatefulWidget {
  final String? transcript;
  final String? unavailableText;
  final String? audioUrl;

  const CommentVoiceReplyView(
      {super.key, this.transcript, this.unavailableText, this.audioUrl});

  @override
  State<CommentVoiceReplyView> createState() => _CommentVoiceReplyViewState();
}

class _CommentVoiceReplyViewState extends State<CommentVoiceReplyView> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.audioUrl?.isNotEmpty ?? false) {
      _player = AudioPlayer();
      _playerStateSubscription = _player!.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state.playing;
          _loading = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
          if (state.processingState == ProcessingState.completed) {
            _playing = false;
          }
        });
      }, onError: (_) {
        if (!mounted) return;
        setState(() {
          _failed = true;
          _playing = false;
          _loading = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlaying() async {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      await player.pause();
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (player.processingState == ProcessingState.idle ||
          player.processingState == ProcessingState.completed) {
        await player.setUrl(widget.audioUrl!);
      }
      await player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var locals = AppLocalizations.of(context)!;
    ColorScheme colors = Theme.of(context).colorScheme;

    final transcript = widget.transcript ?? '';
    final unavailableText = widget.unavailableText ?? '';

    return Container(
      decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, size: 15),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    locals.voiceReply,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_player != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: IconButton(
                      onPressed: _failed ? null : _togglePlaying,
                      icon: _loading
                          ? const SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_playing ? Icons.pause : Icons.play_arrow,
                              size: 20),
                    ),
                  ),
                ],
              ],
            ),
            if (transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(transcript),
              )
            else if (unavailableText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  unavailableText,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            if ((_player == null || _failed) && transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  locals.voiceReplyAudioUnavailable,
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: colors.secondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

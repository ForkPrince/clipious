import 'package:flutter/material.dart';

import '../../../videos/models/chapter.dart';

/// A [Slider] that paints a small tick on the track for each video chapter.
///
/// When the server doesn't support chapters (or the video has none), this
/// behaves exactly like a regular [Slider].
class ChapterSlider extends StatelessWidget {
  final List<Chapter>? chapters;
  final Duration duration;
  final double value;
  final double max;
  final double? secondaryTrackValue;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const ChapterSlider({
    super.key,
    required this.chapters,
    required this.duration,
    required this.value,
    required this.max,
    this.secondaryTrackValue,
    this.onChanged,
    this.onChangeEnd,
  });

  List<double> get _chapterFractions {
    if (duration.inMilliseconds <= 0 ||
        chapters == null ||
        chapters!.length < 2) {
      return const [];
    }

    return chapters!
        .map((chapter) => (chapter.startTime * 1000) / duration.inMilliseconds)
        .where((fraction) => fraction > 0 && fraction < 1)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final fractions = _chapterFractions;
    if (fractions.isEmpty) {
      return Slider(
        min: 0,
        max: max,
        value: value,
        secondaryTrackValue: secondaryTrackValue,
        onChangeEnd: onChangeEnd,
        onChanged: onChanged,
      );
    }

    final theme = Theme.of(context);

    return SliderTheme(
      data: theme.sliderTheme.copyWith(
        trackShape: _ChapterTrackShape(
          chapterFractions: fractions,
          markerColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      child: Slider(
        min: 0,
        max: max,
        value: value,
        secondaryTrackValue: secondaryTrackValue,
        onChangeEnd: onChangeEnd,
        onChanged: onChanged,
      ),
    );
  }
}

class _ChapterTrackShape extends RoundedRectSliderTrackShape {
  final List<double> chapterFractions;
  final Color markerColor;

  const _ChapterTrackShape({
    required this.chapterFractions,
    required this.markerColor,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint paint = Paint()
      ..color = markerColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final fraction in chapterFractions) {
      final double dx = trackRect.left + trackRect.width * fraction;
      context.canvas.drawLine(
        Offset(dx, trackRect.top - 1.5),
        Offset(dx, trackRect.bottom + 1.5),
        paint,
      );
    }
  }
}

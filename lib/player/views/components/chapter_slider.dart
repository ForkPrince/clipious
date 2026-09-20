import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../videos/models/chapter.dart';

/// A [Slider] that paints a small tick on the track for each video chapter and
/// highlights the chapter currently under the thumb.
///
/// While the user drags the slider, a small popup showing the title of the
/// chapter under the thumb is displayed above it.
///
/// When the server doesn't support chapters (or the video has none), this
/// behaves exactly like a regular [Slider].
class ChapterSlider extends StatefulWidget {
  final List<Chapter>? chapters;
  final Duration duration;
  final double value;
  final double max;
  final double? secondaryTrackValue;

  /// Whether the user is currently dragging the slider. The chapter popup is
  /// only shown while this is `true`.
  final bool isDragging;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const ChapterSlider({
    super.key,
    required this.chapters,
    required this.duration,
    required this.value,
    required this.max,
    this.secondaryTrackValue,
    this.isDragging = false,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<ChapterSlider> createState() => _ChapterSliderState();
}

class _ChapterSliderState extends State<ChapterSlider> {
  List<double> get _chapterFractions {
    if (widget.duration.inMilliseconds <= 0 ||
        widget.chapters == null ||
        widget.chapters!.length < 2) {
      return const [];
    }

    return widget.chapters!
        .map((chapter) =>
            (chapter.startTime * 1000) / widget.duration.inMilliseconds)
        .where((fraction) => fraction > 0 && fraction < 1)
        .toList();
  }

  /// The index of the chapter that [positionMs] falls in, or `-1` when the
  /// position is before the first chapter.
  int _chapterIndexAt(double positionMs) {
    final chapters = widget.chapters;
    if (chapters == null || chapters.isEmpty) {
      return -1;
    }

    int index = -1;
    double bestStart = double.negativeInfinity;
    for (int i = 0; i < chapters.length; i++) {
      final double startMs = chapters[i].startTime * 1000;
      if (startMs <= positionMs && startMs >= bestStart) {
        bestStart = startMs;
        index = i;
      }
    }
    return index;
  }

  /// Fraction range `(start, end)` of the chapter currently under the thumb.
  (double, double)? _currentChapterRange() {
    final chapters = widget.chapters;
    final int durationMs = widget.duration.inMilliseconds;
    if (chapters == null || durationMs <= 0) {
      return null;
    }

    final int index = _chapterIndexAt(widget.value);
    if (index < 0) {
      return null;
    }

    final double start =
        (chapters[index].startTime * 1000 / durationMs).clamp(0.0, 1.0);
    final double end = index + 1 < chapters.length
        ? (chapters[index + 1].startTime * 1000 / durationMs).clamp(0.0, 1.0)
        : 1.0;
    if (end <= start) {
      return null;
    }
    return (start, end);
  }

  Chapter? _currentChapter() {
    final int index = _chapterIndexAt(widget.value);
    if (index < 0) {
      return null;
    }
    return widget.chapters![index];
  }

  /// Horizontal alignment in the range `[-1, 1]` that keeps the popup centred
  /// over the slider thumb.
  ///
  /// This mirrors the math used by [Slider] to place its thumb
  /// (see [BaseSliderTrackShape.getPreferredRect]).
  double _thumbAlignment(BuildContext context, double width) {
    if (width <= 0 || widget.max <= 0) {
      return 0;
    }

    final SliderThemeData sliderTheme = SliderTheme.of(context);
    const bool isEnabled = true;
    const bool isDiscrete = false;
    final SliderComponentShape overlayShape =
        sliderTheme.overlayShape ?? const RoundSliderOverlayShape();
    final SliderComponentShape thumbShape =
        sliderTheme.thumbShape ?? const RoundSliderThumbShape();

    final double thumbWidth =
        thumbShape.getPreferredSize(isEnabled, isDiscrete).width;
    final double overlayWidth =
        overlayShape.getPreferredSize(isEnabled, isDiscrete).width;

    final EdgeInsets? padding = sliderTheme.padding?.resolve(TextDirection.ltr);
    final double trackLeft;
    final double trackWidth;
    if (padding != null) {
      trackLeft = padding.left;
      trackWidth = math.max(0.0, width - padding.horizontal);
    } else {
      trackLeft = math.max(overlayWidth / 2, thumbWidth / 2);
      final double rightInset = math.max(thumbWidth, overlayWidth);
      trackWidth = math.max(0.0, width - trackLeft - rightInset);
    }

    double fraction = (widget.value / widget.max).clamp(0.0, 1.0);
    if (Directionality.of(context) == TextDirection.rtl) {
      fraction = 1.0 - fraction;
    }
    final double thumbX = trackLeft + trackWidth * fraction;

    return ((thumbX / width) * 2 - 1).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<double> fractions = _chapterFractions;

    if (fractions.isEmpty) {
      return Slider(
        min: 0,
        max: widget.max,
        value: widget.value,
        secondaryTrackValue: widget.secondaryTrackValue,
        onChangeEnd: widget.onChangeEnd,
        onChanged: widget.onChanged,
      );
    }

    final Chapter? chapter = _currentChapter();
    final bool showPopup = widget.isDragging && chapter != null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double sliderHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 25;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            SliderTheme(
              data: theme.sliderTheme.copyWith(
                trackShape: _ChapterTrackShape(
                  chapterFractions: fractions,
                  markerColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  highlightRange: _currentChapterRange(),
                ),
              ),
              child: Slider(
                min: 0,
                max: widget.max,
                value: widget.value,
                secondaryTrackValue: widget.secondaryTrackValue,
                onChangeEnd: widget.onChangeEnd,
                onChanged: widget.onChanged,
              ),
            ),
            if (showPopup)
              Positioned(
                left: 0,
                right: 0,
                bottom: sliderHeight + 4,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment(
                        _thumbAlignment(context, constraints.maxWidth), 0),
                    heightFactor: 1,
                    child: _ChapterPopup(title: chapter.title),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The popup shown above the thumb while scrubbing, displaying the title of
/// the chapter the thumb is currently over.
class _ChapterPopup extends StatelessWidget {
  final String title;

  const _ChapterPopup({required this.title});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _ChapterTrackShape extends RoundedRectSliderTrackShape {
  final List<double> chapterFractions;
  final Color markerColor;
  final (double, double)? highlightRange;

  const _ChapterTrackShape({
    required this.chapterFractions,
    required this.markerColor,
    this.highlightRange,
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

    final (double, double)? highlight = highlightRange;
    if (highlight != null) {
      final double left = trackRect.left + trackRect.width * highlight.$1;
      final double right = trackRect.left + trackRect.width * highlight.$2;
      if (right > left) {
        final Paint highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.35);
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, trackRect.top, right, trackRect.bottom),
            Radius.circular(trackRect.height / 2),
          ),
          highlightPaint,
        );
      }
    }

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

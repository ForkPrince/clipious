import 'package:clipious/player/views/tv/components/player_controls.dart';
import 'package:clipious/videos/models/chapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required double progress,
    required List<Chapter>? chapters,
    required Duration duration,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: TvChapterProgressBar(
            progress: progress,
            chapters: chapters,
            duration: duration,
          ),
        ),
      ),
    ));
  }

  testWidgets('renders a marker per chapter excluding the video start',
      (tester) async {
    await pumpBar(
      tester,
      progress: 0.5,
      chapters: [
        Chapter('Intro', 0, null),
        Chapter('Middle', 30, null),
        Chapter('End', 60, null),
      ],
      duration: const Duration(seconds: 120),
    );

    // Intro maps to fraction 0 and is not drawn.
    expect(find.byType(Positioned), findsNWidgets(2));
  });

  testWidgets('renders no markers when chapters are unsupported',
      (tester) async {
    await pumpBar(
      tester,
      progress: 0.5,
      chapters: null,
      duration: const Duration(seconds: 120),
    );

    expect(find.byType(TvChapterProgressBar), findsOneWidget);
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('hides itself while progress is unknown', (tester) async {
    await pumpBar(
      tester,
      progress: -1,
      chapters: null,
      duration: const Duration(seconds: 120),
    );

    expect(find.byType(TvChapterProgressBar), findsOneWidget);
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('paints markers above the played progress bar', (tester) async {
    await pumpBar(
      tester,
      progress: 0.5,
      chapters: [
        Chapter('Intro', 0, null),
        Chapter('Middle', 30, null),
      ],
      duration: const Duration(seconds: 120),
    );

    final stack = tester.widget<Stack>(find.descendant(
      of: find.byType(TvChapterProgressBar),
      matching: find.byType(Stack),
    ));
    final playedIndex = stack.children
        .indexWhere((child) => child is AnimatedFractionallySizedBox);
    final markerIndex =
        stack.children.indexWhere((child) => child is Positioned);

    expect(playedIndex, isNonNegative);
    expect(markerIndex, greaterThan(playedIndex));
  });

  testWidgets('markers contrast with the segment underneath them',
      (tester) async {
    await pumpBar(
      tester,
      progress: 0.5,
      chapters: [
        Chapter('Intro', 0, null),
        // 24s / 120s = fraction 0.2, inside the played (white) portion.
        Chapter('Played', 24, null),
        // 84s / 120s = fraction 0.7, inside the unplayed (dark) portion.
        Chapter('Unplayed', 84, null),
      ],
      duration: const Duration(seconds: 120),
    );

    final markers = tester
        .widgetList<Positioned>(find.descendant(
          of: find.byType(TvChapterProgressBar),
          matching: find.byType(Positioned),
        ))
        .toList();
    final playedColor = (markers[0].child as Container).color!;
    final unplayedColor = (markers[1].child as Container).color!;

    // The marker over the white bar must be dark, and the one over the dark
    // bar must be light.
    expect(playedColor.computeLuminance(), lessThan(0.5));
    expect(unplayedColor.computeLuminance(), greaterThan(0.5));
  });
}

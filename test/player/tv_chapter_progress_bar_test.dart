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
}

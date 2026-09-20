import 'package:clipious/player/views/components/chapter_slider.dart';
import 'package:clipious/videos/models/chapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final chapters = [
    Chapter('Intro', 0, null),
    Chapter('Middle', 30, null),
    Chapter('End', 60, null),
  ];

  Future<void> pumpSlider(
    WidgetTester tester, {
    required List<Chapter>? chapters,
    required double value,
    required bool isDragging,
    Duration duration = const Duration(seconds: 120),
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 25,
            child: ChapterSlider(
              chapters: chapters,
              duration: duration,
              value: value,
              max: duration.inMilliseconds.toDouble(),
              isDragging: isDragging,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('shows the chapter title while dragging', (tester) async {
    await pumpSlider(
      tester,
      chapters: chapters,
      value: 40 * 1000,
      isDragging: true,
    );

    expect(find.text('Middle'), findsOneWidget);
  });

  testWidgets('shows the chapter matching the dragged position',
      (tester) async {
    await pumpSlider(
      tester,
      chapters: chapters,
      value: 70 * 1000,
      isDragging: true,
    );

    expect(find.text('End'), findsOneWidget);
    expect(find.text('Middle'), findsNothing);
  });

  testWidgets('hides the popup when not dragging', (tester) async {
    await pumpSlider(
      tester,
      chapters: chapters,
      value: 40 * 1000,
      isDragging: false,
    );

    expect(find.text('Middle'), findsNothing);
  });

  testWidgets('shows no popup before the first chapter', (tester) async {
    await pumpSlider(
      tester,
      chapters: [Chapter('Intro', 10, null), Chapter('Main', 40, null)],
      value: 5 * 1000,
      isDragging: true,
    );

    expect(find.text('Intro'), findsNothing);
  });

  testWidgets('shows no popup when chapters are unsupported', (tester) async {
    await pumpSlider(
      tester,
      chapters: null,
      value: 40 * 1000,
      isDragging: true,
    );

    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows no popup when there is only one chapter', (tester) async {
    await pumpSlider(
      tester,
      chapters: [Chapter('Only', 0, null)],
      value: 10 * 1000,
      isDragging: true,
    );

    expect(find.text('Only'), findsNothing);
  });

  testWidgets('uses a custom track shape to highlight chapters',
      (tester) async {
    await pumpSlider(
      tester,
      chapters: chapters,
      value: 40 * 1000,
      isDragging: false,
    );

    final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(sliderTheme.data.trackShape.runtimeType.toString(),
        '_ChapterTrackShape');
  });

  testWidgets('falls back to a plain slider without chapters', (tester) async {
    await pumpSlider(
      tester,
      chapters: null,
      value: 40 * 1000,
      isDragging: false,
    );

    expect(find.byType(SliderTheme), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
  });
}

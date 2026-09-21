import 'package:clipious/globals.dart';
import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:clipious/utils/models/paginated_list.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:clipious/utils/views/tv/components/tv_horizontal_item_list.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:clipious/videos/views/components/video_thumbnail.dart';
import 'package:clipious/videos/views/tv/components/video_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _longTitle =
    'A very long video title that is guaranteed to wrap onto two whole lines '
    'inside the tiny recommended video tile';
const _longAuthor = 'Some Channel With An Extremely Long Name That Would Wrap';

void main() {
  setUp(() async {
    db = await SembastSqfDb.createInMemory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpItem(
    WidgetTester tester, {
    required double height,
    double textScale = 1.0,
    String title = _longTitle,
    String author = _longAuthor,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          // Only the height is constrained, mirroring the horizontal shelf
          // where tiles get a tight height and a loose width.
          child: SizedBox(
            height: height,
            child: TvVideoItem(
              video: Video(
                videoId: 'dQw4w9WgXcQ',
                title: title,
                author: author,
              ),
              autoFocus: false,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  // The shelf clamps its list height between 120 and 300 logical pixels, so
  // cover that whole range plus a larger grid sized tile.
  for (final height in [120.0, 150.0, 188.0, 250.0, 300.0, 400.0]) {
    testWidgets('does not overflow at height $height', (tester) async {
      await pumpItem(tester, height: height);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('leaves the card the space it needs for both text lines',
      (tester) async {
    await pumpItem(tester, height: 120);

    final title = tester.widget<Text>(find.text(_longTitle));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);

    final author = tester.widget<Text>(find.text(_longAuthor));
    expect(author.maxLines, 1);
    expect(author.overflow, TextOverflow.ellipsis);
  });

  testWidgets('keeps the thumbnail at 16:9 when there is enough room',
      (tester) async {
    await pumpItem(tester, height: 300);

    final thumbnail = tester.getSize(find.byType(VideoThumbnailView));
    expect(thumbnail.width / thumbnail.height, closeTo(16 / 9, 0.01));
  });

  testWidgets('does not overflow with a large text scale', (tester) async {
    await pumpItem(tester, height: 188, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow through the real horizontal shelf',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple)),
      home: Scaffold(
        body: TvHorizontalVideoList(
          height: 188,
          paginatedVideoList: FixedItemList<Video>([
            Video(
              videoId: 'dQw4w9WgXcQ',
              title: _longTitle,
              author: _longAuthor,
            ),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TvVideoItem), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

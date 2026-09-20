import 'package:clipious/videos/models/video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chapter parsing', () {
    test('parses title, startTime and thumbnail', () {
      final chapter = Video.fromJson({
        'videoId': 'abc',
        'chapters': [
          {'title': 'Intro', 'startTime': 0.0, 'thumbnail': 'https://x/0.jpg'},
          {'title': 'Main', 'startTime': 45.5, 'thumbnail': ''},
        ],
      }).chapters;

      expect(chapter, isNotNull);
      expect(chapter!.length, 2);
      expect(chapter[0].title, 'Intro');
      expect(chapter[0].startTime, 0.0);
      expect(chapter[1].title, 'Main');
      expect(chapter[1].startTime, 45.5);
    });

    test('null when the server does not return a chapters key', () {
      final video = Video.fromJson({'videoId': 'abc'});

      expect(video.chapters, isNull);
      expect(video.hasChapters, isFalse);
    });

    test('empty list when the server supports chapters but has none', () {
      final video = Video.fromJson({'videoId': 'abc', 'chapters': <dynamic>[]});

      expect(video.chapters, isNotNull);
      expect(video.chapters, isEmpty);
      expect(video.hasChapters, isFalse);
    });

    test('requires more than one chapter to be considered chaptered', () {
      final video = Video.fromJson({
        'videoId': 'abc',
        'chapters': [
          {'title': 'Only', 'startTime': 0.0},
        ],
      });

      expect(video.chapters, hasLength(1));
      expect(video.hasChapters, isFalse);
    });
  });
}

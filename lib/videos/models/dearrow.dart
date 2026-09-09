import 'package:clipious/extensions.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/videos/models/db/dearrow_cache.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../settings/models/db/settings.dart';

part 'dearrow.g.dart';

@JsonSerializable()
class DeArrow {
  static const _smallWords = {
    'a',
    'an',
    'and',
    'as',
    'at',
    'but',
    'by',
    'for',
    'if',
    'in',
    'nor',
    'of',
    'on',
    'or',
    'per',
    'the',
    'to',
    'via'
  };

  static final _emoji = RegExp(
      '[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}\u{231A}-\u{231B}\u{23E9}-\u{23FA}\u{25AA}-\u{25FE}\u{2934}-\u{2935}\u{2B05}-\u{2B55}\u{3030}\u{303D}\u{3297}\u{3299}]',
      unicode: true);
  static final _firstLetter = RegExp(r'^[^a-z]*[a-z]');

  static String formatTitle(String? text) {
    if (text == null || text.isEmpty) return text ?? '';
    var words = text
        .replaceAll(_emoji, '')
        .replaceAll('>', '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    var out = <String>[];
    for (var i = 0; i < words.length; i++) {
      var word = words[i];
      if (i > 0 &&
          !words[i - 1].endsWith(':') &&
          i < words.length - 1 &&
          _smallWords.contains(word.toLowerCase())) {
        out.add(word.toLowerCase());
      } else {
        var lower = word.toLowerCase();
        out.add(
            lower.replaceFirstMapped(_firstLetter, (m) => m[0]!.toUpperCase()));
      }
    }
    return out.join(' ');
  }

  final List<DeArrowTitle> titles;
  final List<DeArrowThumbnail> thumbnails;
  final double? randomTime;
  final double? videoDuration;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late final String videoId;

  String get thumbBaseUrl =>
      'https://dearrow-thumb.ajay.app/api/v1/getThumbnail?videoID=:id'
          .replaceAll(':id', videoId);

  String? get thumbnailUrl {
    var thumb = thumbnails.firstOrNull;
    var valid = thumb != null && (thumb.votes >= 0 || thumb.locked);
    if (valid && thumb.original) return null;
    if (valid || videoDuration != null) {
      if (valid && thumb.timestamp != null) {
        return '$thumbBaseUrl&time=${thumb.timestamp}';
      }
      if (videoDuration != null) {
        return '$thumbBaseUrl&time=${videoDuration! * (randomTime ?? 0)}';
      }
      return thumbBaseUrl;
    }
    return thumbBaseUrl;
  }

  String resolveTitle(String? originalTitle) {
    var first = titles.firstOrNull;
    if (first != null &&
        (first.votes >= 0 || first.locked) &&
        (first.title?.isNotEmpty ?? false)) {
      return formatTitle(first.title);
    }
    return formatTitle(originalTitle);
  }

  DeArrow({
    required this.titles,
    required this.thumbnails,
    this.randomTime,
    this.videoDuration,
  });

  factory DeArrow.fromJson(Map<String, dynamic> json) =>
      _$DeArrowFromJson(json);

  Map<String, dynamic> toJson() => _$DeArrowToJson(this);

  static Future<List<Video>> processVideos(List<Video>? videos) async {
    var process = db.getSettings(dearrowSettingName)?.value == "true";
    if (videos != null && process && videos.isNotEmpty) {
      bool doThumbnails =
          db.getSettings(dearrowThumbnailsSettingName)?.value == "true";
      List<Video> out = [];
      const chunkSize = 8;
      for (var i = 0; i < videos.length; i += chunkSize) {
        var chunk = videos.sublist(
            i, i + chunkSize > videos.length ? videos.length : i + chunkSize);
        var processed =
            await Future.wait(chunk.map((e) => _deArrowVideo(e, doThumbnails)));
        out.addAll(processed);
      }
      return out;
    } else {
      return videos ?? [];
    }
  }

  static Future<Video> processVideo(Video video) async {
    var process = db.getSettings(dearrowSettingName)?.value == "true";
    if (!process) return video;
    bool doThumbnails =
        db.getSettings(dearrowThumbnailsSettingName)?.value == "true";
    return _deArrowVideo(video, doThumbnails);
  }

  static Future<Video> _deArrowVideo(Video video, bool doThumbnails) async {
    try {
      var cache = db.getDeArrowCache(video.videoId);
      if (cache != null && cache.isStale) cache = null;

      var vid =
          video.copyWith(title: formatTitle(video.title), deArrowed: true);

      if (cache != null) {
        if (cache.title != null) {
          vid = vid.copyWith(title: cache.title!);
        }

        if (!doThumbnails) return vid;

        if (cache.url != null) {
          vid = vid.copyWith(deArrowThumbnailUrl: cache.url);
          return vid;
        }
        if (cache.title != null) return vid;
      }

      var deArrow = await service.getDeArrow(video.videoId);
      if (deArrow != null) {
        vid = vid.copyWith(title: deArrow.resolveTitle(video.title));
        if (doThumbnails) {
          var thumbnail = deArrow.thumbnailUrl;
          if (thumbnail != null) {
            vid = vid.copyWith(deArrowThumbnailUrl: thumbnail);
          }
        }
      }

      DeArrowCache newCache = DeArrowCache(video.videoId);
      newCache.title = vid.title;
      newCache.url = vid.deArrowThumbnailUrl;
      newCache.cachedAt = DateTime.now().millisecondsSinceEpoch;
      await db.upsertDeArrowCache(newCache);

      return vid;
    } catch (err) {
      return video;
    }
  }
}

@JsonSerializable()
class DeArrowTitle {
  final String? title;
  final bool original;
  final int votes;
  final bool locked;
  @JsonKey(name: 'UUID')
  final String? uuid;

  DeArrowTitle(
      {this.title,
      this.original = false,
      this.votes = 0,
      this.locked = false,
      this.uuid});

  factory DeArrowTitle.fromJson(Map<String, dynamic> json) =>
      _$DeArrowTitleFromJson(json);

  Map<String, dynamic> toJson() => _$DeArrowTitleToJson(this);
}

@JsonSerializable()
class DeArrowThumbnail {
  final double? timestamp;
  final bool original;
  final int votes;
  final bool locked;
  @JsonKey(name: 'UUID')
  final String? uuid;

  DeArrowThumbnail(
      {this.timestamp,
      this.original = false,
      this.votes = 0,
      this.locked = false,
      this.uuid});

  factory DeArrowThumbnail.fromJson(Map<String, dynamic> json) =>
      _$DeArrowThumbnailFromJson(json);

  Map<String, dynamic> toJson() => _$DeArrowThumbnailToJson(this);
}

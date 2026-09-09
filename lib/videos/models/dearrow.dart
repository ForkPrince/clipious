import 'package:clipious/extensions.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/videos/models/db/dearrow_cache.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../settings/models/db/settings.dart';

part 'dearrow.g.dart';

@JsonSerializable()
class DeArrow {
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
    for (var thumb in thumbnails) {
      if (thumb.votes < 0 && !thumb.locked) continue;
      if (thumb.original) return null;
      if (thumb.timestamp != null) {
        return '$thumbBaseUrl&time=${thumb.timestamp}';
      }
    }
    return null;
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

      var vid = video.copyWith();

      if (cache != null) {
        if (cache.title != null) {
          vid = vid.copyWith(title: cache.title!, deArrowed: true);
        }

        if (!doThumbnails) return vid;

        if (cache.url != null) {
          vid = vid.copyWith(deArrowThumbnailUrl: cache.url, deArrowed: true);
          return vid;
        }
        if (cache.title != null) return vid;
      }

      var deArrow = await service.getDeArrow(video.videoId);
      if (deArrow == null) return vid;
      var validTitle =
          deArrow.titles.firstWhereOrNull((t) => t.votes >= 0 || t.locked);
      if (validTitle?.title != null && validTitle!.title!.isNotEmpty) {
        vid = vid.copyWith(
            title: validTitle.title ?? video.title, deArrowed: true);
      }
      if (doThumbnails) {
        var thumbnail = deArrow.thumbnailUrl;
        if (thumbnail != null) {
          vid = vid.copyWith(deArrowThumbnailUrl: thumbnail, deArrowed: true);
        }
      }

      DeArrowCache newCache = DeArrowCache(video.videoId);
      newCache.title = validTitle?.title;
      newCache.url = vid.deArrowThumbnailUrl;
      if (newCache.title != null || newCache.url != null) {
        await db.upsertDeArrowCache(newCache);
      } else if (cache == null) {
        DeArrowCache empty = DeArrowCache(video.videoId);
        await db.upsertDeArrowCache(empty);
      }

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

import 'package:json_annotation/json_annotation.dart';

part 'dearrow_cache.g.dart';

@JsonSerializable()
class DeArrowCache {
  static const cacheTtlMs = 7 * 24 * 60 * 60 * 1000;

  String videoId;
  String? title;
  String? url;
  int? cachedAt;
  bool? normalized;

  bool get isStale =>
      cachedAt == null ||
      DateTime.now().millisecondsSinceEpoch - cachedAt! > cacheTtlMs;

  DeArrowCache(this.videoId);

  factory DeArrowCache.fromJson(Map<String, dynamic> json) =>
      _$DeArrowCacheFromJson(json);

  Map<String, dynamic> toJson() => _$DeArrowCacheToJson(this);
}

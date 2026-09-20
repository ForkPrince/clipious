import 'package:json_annotation/json_annotation.dart';

/*
 {
   "title": "Intro",
   "startTime": 0.0,
   "thumbnail": "https://..."
 }
 */
part 'chapter.g.dart';

@JsonSerializable()
class Chapter {
  String title;
  double startTime;
  String? thumbnail;

  Chapter(this.title, this.startTime, this.thumbnail);

  factory Chapter.fromJson(Map<String, dynamic> json) =>
      _$ChapterFromJson(json);

  Map<String, dynamic> toJson() => _$ChapterToJson(this);
}

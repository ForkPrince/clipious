// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chapter _$ChapterFromJson(Map<String, dynamic> json) => Chapter(
      json['title'] as String,
      (json['startTime'] as num).toDouble(),
      json['thumbnail'] as String?,
    );

Map<String, dynamic> _$ChapterToJson(Chapter instance) => <String, dynamic>{
      'title': instance.title,
      'startTime': instance.startTime,
      'thumbnail': instance.thumbnail,
    };

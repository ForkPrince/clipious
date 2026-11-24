// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommentAttachment _$CommentAttachmentFromJson(Map<String, dynamic> json) =>
    CommentAttachment(
      json['type'] as String?,
      (json['imageThumbnails'] as List<dynamic>?)
          ?.map((e) => ImageObject.fromJson(e as Map<String, dynamic>))
          .toList(),
      (json['width'] as num?)?.toInt(),
      (json['height'] as num?)?.toInt(),
      (json['aspectRatio'] as num?)?.toDouble(),
      json['imageFormatHint'] as String?,
      json['isGif'] as bool?,
      json['externalImageId'] as String?,
      json['unavailableText'] as String?,
      json['audioUrl'] as String?,
      json['transcript'] as String?,
      json['transcriptHtml'] as String?,
    );

Map<String, dynamic> _$CommentAttachmentToJson(CommentAttachment instance) =>
    <String, dynamic>{
      'type': instance.type,
      'imageThumbnails': instance.imageThumbnails,
      'width': instance.width,
      'height': instance.height,
      'aspectRatio': instance.aspectRatio,
      'imageFormatHint': instance.imageFormatHint,
      'isGif': instance.isGif,
      'externalImageId': instance.externalImageId,
      'unavailableText': instance.unavailableText,
      'audioUrl': instance.audioUrl,
      'transcript': instance.transcript,
      'transcriptHtml': instance.transcriptHtml,
    };

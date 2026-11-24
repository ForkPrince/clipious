// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_voice_reply.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommentVoiceReply _$CommentVoiceReplyFromJson(Map<String, dynamic> json) =>
    CommentVoiceReply(
      json['transcript'] as String?,
      json['transcriptHtml'] as String?,
      json['unavailableText'] as String?,
      json['audioUrl'] as String?,
    );

Map<String, dynamic> _$CommentVoiceReplyToJson(CommentVoiceReply instance) =>
    <String, dynamic>{
      'transcript': instance.transcript,
      'transcriptHtml': instance.transcriptHtml,
      'unavailableText': instance.unavailableText,
      'audioUrl': instance.audioUrl,
    };

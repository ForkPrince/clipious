import 'package:json_annotation/json_annotation.dart';

part 'comment_voice_reply.g.dart';

@JsonSerializable()
class CommentVoiceReply {
  String? transcript;
  String? transcriptHtml;
  String? unavailableText;
  String? audioUrl;

  CommentVoiceReply(this.transcript, this.transcriptHtml, this.unavailableText,
      this.audioUrl);

  factory CommentVoiceReply.fromJson(Map<String, dynamic> json) =>
      _$CommentVoiceReplyFromJson(json);

  Map<String, dynamic> toJson() => _$CommentVoiceReplyToJson(this);

  bool get hasTranscript => (transcript?.isNotEmpty ?? false);

  bool get hasAudio => (audioUrl?.isNotEmpty ?? false);
}

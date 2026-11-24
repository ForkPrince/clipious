import 'package:clipious/utils/models/image_object.dart';
import 'package:json_annotation/json_annotation.dart';

part 'comment_attachment.g.dart';

@JsonSerializable()
class CommentAttachment {
  String? type;
  List<ImageObject>? imageThumbnails;
  int? width;
  int? height;
  double? aspectRatio;
  String? imageFormatHint;
  bool? isGif;
  String? externalImageId;
  String? unavailableText;

  String? audioUrl;
  String? transcript;
  String? transcriptHtml;

  CommentAttachment(
      this.type,
      this.imageThumbnails,
      this.width,
      this.height,
      this.aspectRatio,
      this.imageFormatHint,
      this.isGif,
      this.externalImageId,
      this.unavailableText,
      this.audioUrl,
      this.transcript,
      this.transcriptHtml);

  factory CommentAttachment.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);

    if (normalized['imageThumbnails'] is! List) {
      normalized['imageThumbnails'] = <Map<String, dynamic>>[];
    }

    return _$CommentAttachmentFromJson(normalized);
  }

  Map<String, dynamic> toJson() => _$CommentAttachmentToJson(this);

  bool get isImage => type == 'image';

  bool get isAudio => type == 'audio';

  bool get isGifValue => isGif ?? false;

  List<ImageObject> get thumbnails =>
      (imageThumbnails ?? []).where((image) => image.url.isNotEmpty).toList();
}

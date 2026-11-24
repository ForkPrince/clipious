import 'dart:convert';

import 'package:clipious/comments/models/comment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gifCommentJson = {
    'author': '@RyuSanjii',
    'authorThumbnails': [
      {'url': 'https://yt3.ggpht.com/avatar=s48', 'width': 48, 'height': 48}
    ],
    'authorId': 'UCHfd1aOIbMf3E9y1aMUcHlg',
    'authorUrl': '/channel/UCHfd1aOIbMf3E9y1aMUcHlg',
    'isEdited': false,
    'content': 'TAK never misses.',
    'publishedText': '2 days ago',
    'likeCount': 1000,
    'commentId': 'UgxCWLozQOezZao-19d4AaABAg',
    'authorIsChannelOwner': false,
    'attachment': {
      'type': 'image',
      'imageThumbnails': [
        {
          'url':
              'https://i.ytimg.com/c_exp/UgxCWLozQOezZao-19d4AaABAg/IMafAXACgPDdI_webp_animated_original_aspect_ratio.webp?sqp=CIGmtNcGGOCoAQ==&rs=AOn4CLD6Fr7uz48Vrso5SgKGuaCHZ0-4Zw',
          'width': 220,
          'height': 166
        }
      ],
      'width': 220,
      'height': 166,
      'aspectRatio': 1.3253012,
      'imageFormatHint': 'IMAGE_FORMAT_ANIMATED_WEBP',
      'isGif': true,
      'externalImageId': 'IMafAXACgPDdI',
      'unavailableText': 'GIF unavailable'
    }
  };

  const voiceCommentJson = {
    'author': 'Creator',
    'authorThumbnails': [
      {'url': 'https://yt3.ggpht.com/avatar2=s48', 'width': 48, 'height': 48}
    ],
    'authorId': 'UCvoice',
    'authorUrl': '/channel/UCvoice',
    'isEdited': false,
    'content': 'Transcribed voice reply',
    'publishedText': '2 days ago',
    'likeCount': 7,
    'commentId': 'UgyVoiceComment',
    'authorIsChannelOwner': true,
    'voiceReply': {
      'transcript': 'Thanks everyone!',
      'transcriptHtml': 'Thanks everyone!',
      'unavailableText': 'Voice reply unavailable'
    }
  };

  test('GIF comment parses its image attachment', () {
    final comment = Comment.fromJson(gifCommentJson);
    final attachment = comment.attachment;
    expect(attachment, isNotNull);
    expect(attachment!.isImage, isTrue);
    expect(attachment.isGifValue, isTrue);
    expect(attachment.width, 220);
    expect(attachment.height, 166);
    expect(attachment.aspectRatio, closeTo(1.3253012, 0.000001));
    expect(attachment.imageFormatHint, 'IMAGE_FORMAT_ANIMATED_WEBP');
    expect(attachment.externalImageId, 'IMafAXACgPDdI');
    expect(attachment.unavailableText, 'GIF unavailable');
    expect(attachment.thumbnails, hasLength(1));
    expect(attachment.thumbnails.first.url,
        contains('i.ytimg.com/c_exp/UgxCWLozQOezZao-19d4AaABAg/'));
    expect(attachment.thumbnails.first.url, contains('_webp_animated_'));
    expect(comment.voiceReply, isNull);
  });

  test('voice reply comment parses its transcript', () {
    final comment = Comment.fromJson(voiceCommentJson);
    final voiceReply = comment.voiceReply;
    expect(voiceReply, isNotNull);
    expect(voiceReply!.transcript, 'Thanks everyone!');
    expect(voiceReply.transcriptHtml, 'Thanks everyone!');
    expect(voiceReply.unavailableText, 'Voice reply unavailable');
    expect(voiceReply.hasTranscript, isTrue);
    expect(voiceReply.hasAudio, isFalse);
    expect(voiceReply.audioUrl, isNull);
    expect(comment.attachment, isNull);
  });

  test('voice reply with an audio URL exposes it', () {
    final json = Map<String, dynamic>.from(voiceCommentJson);
    json['voiceReply'] = {
      'transcript': 'Thanks everyone!',
      'transcriptHtml': 'Thanks everyone!',
      'unavailableText': '',
      'audioUrl': 'https://example.com/voice-reply.mp3'
    };
    final comment = Comment.fromJson(json);
    expect(comment.voiceReply!.hasAudio, isTrue);
    expect(comment.voiceReply!.audioUrl, 'https://example.com/voice-reply.mp3');
  });

  test('comments from stock Invidious have no media fields', () {
    final json = Map<String, dynamic>.from(gifCommentJson)
      ..remove('attachment');
    final comment = Comment.fromJson(json);
    expect(comment.attachment, isNull);
    expect(comment.voiceReply, isNull);
    expect(comment.content, 'TAK never misses.');
  });

  test('attachment without thumbnails does not throw', () {
    final json = Map<String, dynamic>.from(gifCommentJson);
    json['attachment'] = {'type': 'image', 'isGif': false};
    final comment = Comment.fromJson(json);
    expect(comment.attachment!.isImage, isTrue);
    expect(comment.attachment!.thumbnails, isEmpty);
    expect(comment.attachment!.isGifValue, isFalse);
  });

  test('non-image attachment types parse without crashing', () {
    final json = Map<String, dynamic>.from(gifCommentJson);
    json['attachment'] = {'type': 'video', 'videoId': 'dQw4w9WgXcQ'};
    final comment = Comment.fromJson(json);
    expect(comment.attachment!.isImage, isFalse);
    expect(comment.attachment!.isAudio, isFalse);
  });

  test('attachment and voice reply round-trip through toJson', () {
    final comment = Comment.fromJson(gifCommentJson);
    final roundTripped = Comment.fromJson(
        jsonDecode(jsonEncode(comment.toJson())) as Map<String, dynamic>);
    expect(roundTripped.attachment!.externalImageId, 'IMafAXACgPDdI');
    expect(roundTripped.attachment!.isGifValue, isTrue);
    expect(roundTripped.attachment!.thumbnails.first.width, 220);

    final voice = Comment.fromJson(voiceCommentJson);
    final voiceRoundTripped = Comment.fromJson(
        jsonDecode(jsonEncode(voice.toJson())) as Map<String, dynamic>);
    expect(voiceRoundTripped.voiceReply!.transcript, 'Thanks everyone!');
  });
}

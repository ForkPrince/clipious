import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/settings/models/errors/server_already_exists.dart';
import 'package:clipious/settings/models/errors/wrong_thumbnail_url.dart';

import '../../globals.dart';
import '../models/db/server.dart';

part 'add_server.freezed.dart';

class AddServerCubit extends Cubit<AddServerState> {
  final TextEditingController urlController =
      TextEditingController(text: 'https://');
  final TextEditingController headerNameController = TextEditingController();
  final TextEditingController headerValueController = TextEditingController();

  AddServerCubit(super.initialState) {
    urlController.addListener(
      () {
        emit(state.copyWith(valid: validUrl));
      },
    );
  }

  @override
  Future<void> close() {
    urlController.dispose();
    headerNameController.dispose();
    headerValueController.dispose();
    return super.close();
  }

  Future<Server?> validateServer() async {
    emit(state.copyWith(loading: true));
    try {
      var serverUrl = urlController.value.text.trim();

      final existingServer = db.getServer(serverUrl);

      if (existingServer != null) {
        throw ServerAlreadyExists();
      }

      if (serverUrl.endsWith("/")) {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
      }

      await service.validateServer(serverUrl, state.headers);

      if (state.advancedTest) {
        Server server = Server(url: serverUrl, customHeaders: state.headers);
        final video =
            await service.getVideo('dQw4w9WgXcQ', serverOverride: server);

        final thumbnails = video.videoThumbnails;
        // Validate the resolved URLs that the image loader uses. One usable
        // candidate is enough because the loader tries the available sizes.
        if (thumbnails.isNotEmpty &&
            !thumbnails.any((thumbnail) {
              if (thumbnail.url.trim().isEmpty) return false;
              final url =
                  Uri.tryParse(_resolveThumbnailUrl(thumbnail.url, server));
              return url != null &&
                  const {'http', 'https'}.contains(url.scheme) &&
                  url.host.isNotEmpty;
            })) {
          throw WrongThumbnailUrl();
        }
      }

      return Server(url: serverUrl, customHeaders: state.headers);
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  void setShowAdvanced(bool advanced) {
    emit(state.copyWith(showAdvanced: advanced));
  }

  void addHeader(String key, String value) {
    final Map<String, String> headers = Map.from(state.headers);
    headers[key] = value;
    emit(state.copyWith(headers: headers));
  }

  void removeHeader(String key) {
    final Map<String, String> headers = Map.from(state.headers);
    headers.remove(key);
    emit(state.copyWith(headers: headers));
  }

  bool get validUrl {
    var regExp = RegExp(r'^(http://|https://)');
    if (!urlController.text.trim().startsWith(regExp)) {
      return false;
    }

    final urlWithoutProtocol = urlController.text.replaceAll(regExp, "").trim();

    if (urlWithoutProtocol.isEmpty) {
      return false;
    }

    return true;
  }

  void setAdvancedTest(bool advancedTest) {
    emit(state.copyWith(advancedTest: advancedTest));
  }
}

/// Resolve a thumbnail URL the way the image loader would: absolute http(s)
/// URLs pass through, instance-relative paths resolve against the server.
/// (Videre's invidiousImageUrl() does the same plus instance-proxy routing,
/// which Clipious does not have.)
String _resolveThumbnailUrl(String url, Server server) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return '';
  if (parsed.hasScheme) return trimmed;
  final base = Uri.tryParse(server.url);
  if (base == null) return '';
  return base.resolve(trimmed).toString();
}

@freezed
sealed class AddServerState with _$AddServerState {
  const factory AddServerState(
      {@Default(false) bool loading,
      @Default(false) bool valid,
      @Default(false) bool showAdvanced,
      @Default(true) bool advancedTest,
      @Default({}) Map<String, String> headers}) = _AddServerState;
}

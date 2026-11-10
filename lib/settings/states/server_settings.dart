import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';

import '../../app/states/app.dart';
import '../../globals.dart';
import '../models/db/server.dart';

part 'server_settings.freezed.dart';

final _log = Logger('ServerSettingsCubit');

class ServerSettingsCubit extends Cubit<ServerSettingsState> {
  final AppCubit app;
  Future<void> _serverUpdates = Future.value();

  ServerSettingsCubit(super.initialState, this.app) {
    canDelete();
  }

  Server _savedServer() {
    final saved = db.getServer(state.server.url);
    if (saved == null) throw StateError('Server no longer exists');
    return saved;
  }

  Future<Server> _updateServer(Server Function(Server) update) {
    final result = _serverUpdates.then((_) async {
      final updated = update(_savedServer());
      await db.upsertServer(updated);
      await fileDb.upsertServer(updated);
      return updated;
    });
    // Keep later edits usable after a failed save; callers still receive errors.
    _serverUpdates = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> useServer(bool value) async {
    await db.useServer(state.server);
    try {
      await service.validateCurrentSession();
    } catch (error, stackTrace) {
      _log.warning(
        'Unable to validate the stored Invidious session',
        error,
        stackTrace,
      );
    }
    final Server s = await db.getCurrentlySelectedServer();
    await fileDb.useServer(s);
    emit(state.copyWith(server: s));
    app.setServer(s);
  }

  Future<void> addHeader(String key, String value) async {
    final updated = await _updateServer((saved) =>
        saved.copyWith(customHeaders: {...saved.customHeaders, key: value}));
    emit(state.copyWith.server(customHeaders: updated.customHeaders));
  }

  Future<void> removeHeader(String key) async {
    final updated = await _updateServer((saved) => saved.copyWith(
        customHeaders: Map<String, String>.from(saved.customHeaders)
          ..remove(key)));
    emit(state.copyWith.server(customHeaders: updated.customHeaders));
  }

  Future<void> logOut() async {
    final updated = await _updateServer(
        (saved) => saved.copyWith(sidCookie: null, authToken: null));
    if (updated.inUse) {
      await fileDb.useServer(updated);
    }
    emit(state.copyWith(server: updated));
    // we only refresh the app if the app is currently on this server
    if (app.state.server?.url == updated.url) {
      app.setServer(updated.copyWith());
    }
  }

  Future<void> logInWithToken() async {
    final serverUrl = state.server.url;
    await service.logIn(serverUrl);
    final server = db.getServer(serverUrl)!;
    if (!isClosed) emit(state.copyWith(server: server));
    // Only refresh the app if it is still on the authenticated server.
    if (!app.isClosed && app.state.server?.url == server.url) {
      app.setServer(server);
    }
  }

  Future<void> logInWithCookie(String username, String password) async {
    final saved = _savedServer();
    String cookie = await service.loginWithCookies(
        saved.url, username, password,
        headers: saved.customHeaders);
    // Authentication can outlive this screen or another server edit/switch.
    final updated =
        await _updateServer((latest) => latest.copyWith(sidCookie: cookie));
    if (updated.inUse) {
      fileDb.useServer(updated);
    }
    emit(state.copyWith(server: updated));
    // we only refresh the app if the app is currently on this server
    if (app.state.server?.url == updated.url) {
      app.setServer(updated);
    }
  }

  Future<void> deleteServer() async {
    await db.deleteServer(state.server);

    Server currentServer = await db.getCurrentlySelectedServer();
    emit(state.copyWith());
    app.setServer(currentServer);
  }

  Future<void> canDelete() async {
    bool canDelete = (await db.getServers()).length > 1;
    emit(state.copyWith(canDelete: canDelete));
  }
}

@freezed
sealed class ServerSettingsState with _$ServerSettingsState {
  const factory ServerSettingsState(
      {required Server server,
      @Default(false) bool canDelete}) = _ServerSettingsState;

  const ServerSettingsState._();

  bool get hasBasicAuth => server.customHeaders.containsKey("Authorization");
}

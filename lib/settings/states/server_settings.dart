import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../app/states/app.dart';
import '../../globals.dart';
import '../models/db/server.dart';

part 'server_settings.freezed.dart';

class ServerSettingsCubit extends Cubit<ServerSettingsState> {
  final AppCubit app;

  ServerSettingsCubit(super.initialState, this.app) {
    canDelete();
  }

  Future<void> useServer(bool value) async {
    await db.useServer(state.server);
    await fileDb.useServer(state.server);
    Server s = state.server.copyWith(inUse: true);
    emit(state.copyWith(server: s));
    app.setServer(state.server);
  }

  void addHeader(String key, String value) {
    final Map<String, String> headers = Map.from(state.server.customHeaders);
    headers[key] = value;
    emit(state.copyWith.server(customHeaders: headers));
    db.upsertServer(state.server);
    fileDb.upsertServer(state.server);
  }

  void removeHeader(String key) {
    final Map<String, String> headers = Map.from(state.server.customHeaders);
    headers.remove(key);
    emit(state.copyWith.server(customHeaders: headers));
    db.upsertServer(state.server);
    fileDb.upsertServer(state.server);
  }

  Future<void> logOut() async {
    Server s = state.server.copyWith(sidCookie: null, authToken: null);
    await db.upsertServer(s);
    if (s.inUse) {
      await fileDb.useServer(s);
    }
    emit(state.copyWith(server: s));
    // we only refresh the app if the app is currently on this server
    if (app.state.server?.url == s.url) {
      app.setServer(s.copyWith());
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
    var s = state.server.copyWith();
    String cookie = await service.loginWithCookies(s.url, username, password,
        headers: s.customHeaders);
    s = s.copyWith(sidCookie: cookie);
    await db.upsertServer(s);
    if (s.inUse) {
      fileDb.useServer(s);
    }
    emit(state.copyWith(server: s));
    // we only refresh the app if the app is currently on this server
    if (app.state.server?.url == s.url) {
      app.setServer(s);
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

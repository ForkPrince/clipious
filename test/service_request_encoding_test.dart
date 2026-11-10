import 'dart:convert';

import 'package:clipious/globals.dart';
import 'package:clipious/service.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/settings/models/db/settings.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Service request encoding', () {
    setUp(() async {
      db = await SembastSqfDb.createInMemory();
      await db.upsertServer(const Server(url: 'https://inv.example'));
    });

    tearDown(() => db.close());

    test('continuations survive every paginated endpoint unchanged', () async {
      const continuation = 'next+page/==&cursor=%2B#fragment';
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.queryParameters['continuation'], continuation);
        expect(request.url.queryParameters, isNot(contains('cursor')));
        expect(request.url.hasFragment, isFalse);
        return http.Response('{"videos":[],"playlists":[],"comments":[]}', 200);
      });
      addTearDown(client.close);
      final api = Service(httpClient: client);

      await api.getComments('video-id', continuation: continuation);
      await api.getChannelVideos('channel-id', continuation);
      await api.getChannelStreams('channel-id', continuation);
      await api.getChannelShorts('channel-id', continuation);
      await api.getChannelPlaylists('channel-id', continuation: continuation);

      expect(paths, hasLength(5));
    });

    test('search and suggestions encode query text exactly once', () async {
      const query = 'C++ & 50% #music / caf\u00e9';
      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], query);
        return http.Response(
            request.url.path == urlSearch
                ? '[]'
                : jsonEncode({'query': query, 'suggestions': <String>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      addTearDown(client.close);
      final api = Service(httpClient: client);

      await api.search(query);
      await api.getSearchSuggestion(query);
    });

    test('proxy parameter leaves caller queries untouched', () async {
      await db.saveSetting(SettingsValue(useProxySettingName, 'true'));
      const query = {'continuation': 'next+page', 'omitted': null};
      final request = await Service().buildRequest(
          '/api/v1/comments/video-id?source=youtube',
          query: query);

      expect(request.uri.queryParameters, {
        'source': 'youtube',
        'continuation': 'next+page',
        'local': 'true',
      });
      expect(query, {'continuation': 'next+page', 'omitted': null});
    });

    test('suggestions decode entities without treating text as markup',
        () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'query': 'test',
            'suggestions': [
              'it&#x27;s &#39;quoted&#39; &amp; named',
              'music &#x1F3B5;',
              '<b>literal</b> &lt;tag&gt;',
              'plain  text; &#oops; &#;',
              'bad codepoint: &#1114112;',
            ]
          }),
          200));
      addTearDown(client.close);

      final result =
          await Service(httpClient: client).getSearchSuggestion('test');

      expect(result.suggestions, [
        "it's 'quoted' & named",
        'music \u{1F3B5}',
        '<b>literal</b> <tag>',
        'plain  text; &#oops; &#;',
        'bad codepoint: \uFFFD',
      ]);
    });
  });
}

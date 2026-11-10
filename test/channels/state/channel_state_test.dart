import 'dart:async';

import 'package:clipious/channels/models/channel.dart';
import 'package:clipious/channels/models/channel_sort_by.dart';
import 'package:clipious/channels/states/channel.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ChannelService extends Service {
  final responses = <Completer<Channel>>[];

  @override
  Future<Channel> getChannel(String channelId) {
    final response = Completer<Channel>();
    responses.add(response);
    return response.future;
  }

  // Clipious still loads the subscription state with the channel details,
  // unlike Videre, where it moved to a separate cubit.
  @override
  Future<bool> isSubscribedToChannel(String channelId) => Future.value(false);
}

Channel _channel() => Channel('Channel', 'channel', '/channel/channel', [], [],
    10, 100, 0, false, true, 'Description', [], []);

void main() {
  late Service originalService;
  late _ChannelService channelService;

  setUp(() {
    originalService = service;
    service = channelService = _ChannelService();
  });

  tearDown(() => service = originalService);

  test('channel loading coalesces requests and preserves changed sorting',
      () async {
    final cubit = ChannelCubit(const ChannelController(channelId: 'channel'));
    addTearDown(cubit.close);
    final loading = cubit.onReady();
    expect(channelService.responses, hasLength(1));
    cubit.onSortByChanged(ChannelSortBy.oldest);
    channelService.responses.single.complete(_channel());
    await loading;
    expect(cubit.state.channel?.authorId, 'channel');
    expect(cubit.state.sortBy, ChannelSortBy.oldest);
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.hasError, isFalse);
  });

  test('failed channel loads stop loading and allow retry', () async {
    final cubit = ChannelCubit(const ChannelController(channelId: 'channel'));
    addTearDown(cubit.close);
    final loading = cubit.onReady();
    channelService.responses.single.completeError(StateError('offline'));
    await loading;
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.hasError, isTrue);

    final retry = cubit.onReady();
    expect(cubit.state.loading, isTrue);
    expect(cubit.state.hasError, isFalse);
    expect(channelService.responses, hasLength(2));
    channelService.responses.last.complete(_channel());
    await retry;
    expect(cubit.state.channel?.authorId, 'channel');
    expect(cubit.state.hasError, isFalse);
  });

  for (final fails in [false, true]) {
    test('closed channel ignores late ${fails ? 'failure' : 'success'}',
        () async {
      final cubit = ChannelCubit(const ChannelController(channelId: 'channel'));
      final loading = cubit.onReady();
      await cubit.close();
      if (fails) {
        channelService.responses.single.completeError(StateError('offline'));
      } else {
        channelService.responses.single.complete(_channel());
      }
      await loading;
      await cubit.onReady();
      expect(channelService.responses, hasLength(1));
    });
  }
}

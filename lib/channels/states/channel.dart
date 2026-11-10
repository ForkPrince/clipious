import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/channels/models/channel_sort_by.dart';
import 'package:logging/logging.dart';

import '../../globals.dart';
import '../models/channel.dart';

part 'channel.freezed.dart';

class ChannelCubit extends Cubit<ChannelController> {
  Future<void>? _load;

  ChannelCubit(super.initialState) {
    onReady();
  }

  Future<void> onReady() =>
      _load ??= _loadChannel().whenComplete(() => _load = null);

  Future<void> _loadChannel() async {
    if (isClosed) return;
    emit(state.copyWith(loading: true, hasError: false));
    try {
      Channel channel = await service.getChannel(state.channelId);
      bool isSubscribed = await service.isSubscribedToChannel(state.channelId);

      if (!isClosed) {
        emit(state.copyWith(
            channel: channel, loading: false, isSubscribed: isSubscribed));
      }
    } catch (error, stackTrace) {
      Logger('Channel').warning('Could not load channel', error, stackTrace);
      if (!isClosed) emit(state.copyWith(loading: false, hasError: true));
    }
  }

/*
  @override
  close() async {
    state.controller?.dispose();
    super.close();
  }
*/

  Future<void> toggleSubscription() async {
    var state = this.state.copyWith();
    if (state.channel != null) {
      if (state.isSubscribed) {
        await service.unSubscribe(state.channel!.authorId);
      } else {
        await service.subscribe(state.channel!.authorId);
      }
      bool isSubscribed =
          await service.isSubscribedToChannel(state.channel!.authorId);

      emit(state.copyWith(isSubscribed: isSubscribed));
    }
  }

  void onSortByChanged(ChannelSortBy newValue) {
    emit(state.copyWith(sortBy: newValue));
  }
}

@freezed
sealed class ChannelController with _$ChannelController {
  const factory ChannelController(
          {required String channelId,
          @Default(false) bool isSubscribed,
          Channel? channel,
          @Default(true) bool loading,
          @Default(false) bool hasError,
          @Default(false) bool smallHeader,
          @Default(200) double barHeight,
          @Default(1) double barOpacity,
          @Default(ChannelSortBy.newest) ChannelSortBy sortBy}) =
      _ChannelController;
}

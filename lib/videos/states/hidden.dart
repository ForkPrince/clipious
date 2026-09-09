import 'package:bloc/bloc.dart';
import 'package:clipious/utils/states/item_list.dart';
import 'package:clipious/videos/states/hidden_videos.dart';

class HiddenCubit extends Cubit<void> {
  final ItemListCubit<String> hiddenListCubit;

  HiddenCubit(super.initialState, this.hiddenListCubit);

  Future<void> unhideFromHidden(String videoId) async {
    await HiddenVideosCubit.instance.unhideVideo(videoId);
    hiddenListCubit.refreshItems();
  }
}

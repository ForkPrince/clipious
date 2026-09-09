import 'package:bloc/bloc.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/utils/states/item_list.dart';

class HiddenCubit extends Cubit<void> {
  final ItemListCubit<String> hiddenListCubit;

  HiddenCubit(super.initialState, this.hiddenListCubit);

  Future<void> unhideFromHidden(String videoId) async {
    await service.unhideVideo(videoId);
    hiddenListCubit.refreshItems();
  }
}

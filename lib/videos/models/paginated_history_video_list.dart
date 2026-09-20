import 'package:clipious/globals.dart';
import 'package:clipious/utils/models/paginated_list.dart';
import 'package:clipious/videos/models/db/history_video_cache.dart';
import 'package:clipious/videos/models/video.dart';

class PaginatedHistoryVideoList extends PaginatedVideoList {
  final int maxResults;
  int page = 1;
  bool hasMore = true;

  PaginatedHistoryVideoList({this.maxResults = 20});

  Future<List<Video>> _fetchPage(int page, int maxResults) async {
    List<String> videoIds = await service.getUserHistory(page, maxResults);
    hasMore = videoIds.length == maxResults;
    List<Video?> videos = await Future.wait(videoIds.map((id) async {
      try {
        var cached = await HistoryVideoCache.fromVideoIdToVideo(id);
        return cached.toVideo();
      } catch (_) {
        return null;
      }
    }));
    return videos.whereType<Video>().toList();
  }

  @override
  Future<List<Video>> getItems() async {
    return await _fetchPage(page, maxResults);
  }

  @override
  Future<List<Video>> getMoreItems() async {
    try {
      page++;
      return await getItems();
    } catch (err) {
      page--;
      rethrow;
    }
  }

  @override
  Future<List<Video>> refresh() async {
    page = 1;
    return await _fetchPage(1, maxResults);
  }

  @override
  bool getHasMore() {
    return hasMore;
  }

  @override
  bool hasRefresh() {
    return true;
  }
}

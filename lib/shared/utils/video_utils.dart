import 'package:video_player/video_player.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';

/// Initializes a [VideoPlayerController].
/// - Cache hit  → plays instantly from local file (zero network wait).
/// - Cache miss → streams via network for immediate start, AND kicks off a
///   background download so the next call uses the cached file.
/// Returns null if initialization fails.
Future<VideoPlayerController?> initCachedVideoController(
  String url, {
  double volume = 0,
}) async {
  try {
    final opts = VideoPlayerOptions(mixWithOthers: true);
    final cached = await VideoCacheManager().getFileFromCache(url);

    VideoPlayerController ctrl;
    if (cached != null && await cached.file.exists()) {
      ctrl = VideoPlayerController.file(cached.file, videoPlayerOptions: opts);
    } else {
      prefetchVideo(url); // warm the cache for the next visit
      ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: opts,
      );
    }

    await ctrl.initialize();
    await ctrl.setLooping(true);
    await ctrl.setVolume(volume);
    await ctrl.play();
    return ctrl;
  } catch (_) {
    return null;
  }
}

/// Fire-and-forget download of [url] into [VideoCacheManager].
/// Errors are silently discarded — pure background warm-up.
void prefetchVideo(String url) {
  if (url.isEmpty) return;
  VideoCacheManager().downloadFile(url).then<void>((_) {}).catchError((_) {});
}

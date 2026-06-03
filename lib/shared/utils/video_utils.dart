import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';

/// Инициализирует VideoPlayerController через локальный кэш.
/// При ошибке — фолбэк на прямой network-запрос.
/// Возвращает null если оба варианта провалились.
/// [volume] — 0 для превью в сетке, 1.0 для полного просмотра.
Future<VideoPlayerController?> initCachedVideoController(
  String url, {
  double volume = 0,
}) async {
  try {
    final fileInfo = await VideoCacheManager().downloadFile(url);
    final file = File(fileInfo.file.path);
    if (!await file.exists()) return null;

    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    await ctrl.setLooping(true);
    await ctrl.setVolume(volume);
    await ctrl.play();
    return ctrl;
  } catch (_) {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(volume);
      await ctrl.play();
      return ctrl;
    } catch (_) {
      return null;
    }
  }
}

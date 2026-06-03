import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'appImageCache';
  static final AppCacheManager _instance = AppCacheManager._();
  factory AppCacheManager() => _instance;

  AppCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
    ),
  );
}

/// Отдельный кэш для видео-превью шаблонов.
/// Хранит до 50 видео, TTL 3 дня.
class VideoCacheManager extends CacheManager {
  static const key = 'appVideoCache';
  static final VideoCacheManager _instance = VideoCacheManager._();
  factory VideoCacheManager() => _instance;

  VideoCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 50,
    ),
  );
}

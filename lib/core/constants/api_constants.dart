class ApiConstants {
  ApiConstants._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/v1',
  );

  static const String minioBase = String.fromEnvironment(
    'STORAGE_BASE_URL',
    defaultValue: 'https://pub-aa7161300fa94455ba1b654a828b98a1.r2.dev',
  );

  static const String generateEndpoint = '/generate';
  static const String templatesEndpoint = '/templates';
  static const String statusEndpoint = '/status';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;

  // Patches URLs returned by the backend that reference localhost storage
  static String? fixUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceAll('http://localhost:9000', minioBase);
  }
}

import 'package:trimvo/core/constants/api_constants.dart';

class JobModel {
  const JobModel({
    required this.id,
    required this.status,
    this.progress = 0,
    this.resultUrl,
    this.previewUrl,
    this.thumbUrl,
    this.originalUrl,
    this.error,
    this.gemsCost = 0,
    this.templateId,
    this.createdAt,
    this.jobType,
    this.imageUrls = const [],
    this.aspectRatio,
  });

  final String id;
  final String status;
  final int progress;
  final String? resultUrl;
  final String? previewUrl;
  final String? thumbUrl;
  final String? originalUrl;
  final String? error;
  final int gemsCost;
  final String? templateId;
  final DateTime? createdAt;
  final String? jobType;

  /// e.g. "1:1", "3:4", "4:3", "16:9" — returned by the API for image jobs
  final String? aspectRatio;

  /// Все варианты сгенерированных фото (только для job_type == "image").
  /// Парсится из result_urls[].
  final List<String> imageUrls;

  /// Width / height ratio for the card. Falls back to sensible defaults.
  double get cardAspectRatio {
    // Parse stored aspect ratio string (e.g. "3:4" → 3/4)
    if (aspectRatio != null) {
      final parts = aspectRatio!.split(':');
      if (parts.length == 2) {
        final w = double.tryParse(parts[0]);
        final h = double.tryParse(parts[1]);
        if (w != null && h != null && h > 0) return w / h;
      }
    }
    // Image jobs without ratio → square fallback; API returns the real ratio when known
    if (isImageJob) return 1.0;
    // Video jobs → portrait 9:16
    return 9 / 16;
  }

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'queued';

  bool get isImageJob => jobType == 'image' || _isImageUrl(resultUrl);

  bool get hasMultipleImages => jobType == 'image' && imageUrls.length > 1;

  /// Первый вариант фото для image-джоба, иначе стандартный result_url.
  String? get primaryImageUrl =>
      jobType == 'image' ? imageUrls.firstOrNull : resultUrl;

  static bool _isImageUrl(String? url) {
    if (url == null) return false;
    final lower = url.split('?').first.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  String? get playbackUrl => previewUrl ?? resultUrl ?? originalUrl;
  String? get fullUrl => originalUrl ?? resultUrl;

  factory JobModel.fromJson(Map<String, dynamic> json) {
    // Для image-джобов берём result_urls[], для остальных — result_url
    final rawResultUrls = json['result_urls'];
    List<String> parsedImageUrls;
    if (rawResultUrls is List && rawResultUrls.isNotEmpty) {
      parsedImageUrls = rawResultUrls
          .map((e) => ApiConstants.fixUrl(e?.toString()) ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      final single = ApiConstants.fixUrl(
          (json['result_url'] ?? json['result_path'])?.toString());
      parsedImageUrls =
          (single != null && single.isNotEmpty) ? [single] : const [];
    }

    return JobModel(
      id: json['id']?.toString() ?? json['job_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      resultUrl: ApiConstants.fixUrl(
          (json['result_url'] ?? json['result_path'])?.toString()),
      previewUrl: ApiConstants.fixUrl(
          (json['preview_url'] ?? json['result_path'])?.toString()),
      thumbUrl: ApiConstants.fixUrl(json['thumb_url']?.toString()),
      originalUrl: ApiConstants.fixUrl(json['original_url']?.toString()),
      error: json['error']?.toString(),
      gemsCost: (json['gems_cost'] as num?)?.toInt() ?? 0,
      templateId: json['template_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      jobType: json['job_type']?.toString(),
      imageUrls: parsedImageUrls,
      aspectRatio: json['aspect_ratio']?.toString(),
    );
  }
}

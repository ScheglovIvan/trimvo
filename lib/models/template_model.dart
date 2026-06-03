import 'package:trimvo/services/api_service.dart';

class TemplateModel {
  const TemplateModel({
    required this.id,
    required this.title,
    this.description,
    this.thumbUrl,
    this.previewUrl,
    this.previewCompressedUrl,
    this.gifUrl,
    this.videoUrl,
    this.likes = 0,
    this.plays = 0,
    this.gemsCost = 200,
    this.photoSlots = 1,
    this.hasMaleSlot = false,
    this.hasFemaleSlot = false,
  });

  final String id;
  final String title;
  final String? description;
  final String? thumbUrl;
  final String? previewUrl;
  final String? previewCompressedUrl;
  final String? gifUrl;
  final String? videoUrl;
  final int likes;
  final int plays;
  final int gemsCost;
  final int photoSlots;
  final bool hasMaleSlot;
  final bool hasFemaleSlot;

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      thumbUrl: ApiService.fixUrl(json['thumb_url']?.toString()),
      previewUrl: ApiService.fixUrl(json['preview_url']?.toString()),
      previewCompressedUrl: ApiService.fixUrl(json['preview_compressed_url']?.toString()),
      gifUrl: ApiService.fixUrl(json['gif_url']?.toString()),
      videoUrl: ApiService.fixUrl(json['video_url']?.toString()),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      plays: (json['plays'] as num?)?.toInt() ?? 0,
      gemsCost: (json['gems_cost'] as num?)?.toInt() ?? 200,
      photoSlots: (json['photo_slots'] as num?)?.toInt() ?? 1,
      hasMaleSlot: json['has_male_slot'] as bool? ?? false,
      hasFemaleSlot: json['has_female_slot'] as bool? ?? false,
    );
  }
}

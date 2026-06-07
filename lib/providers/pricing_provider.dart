import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/services/api_service.dart';

class PricingModel {
  const PricingModel({
    this.video5sStandard = 10,
    this.video5sHd = 20,
    this.video5sUltraHd = 35,
    this.video10sStandard = 15,
    this.video10sHd = 25,
    this.video10sUltraHd = 40,
    this.imagePerPhoto = 150,
    this.svipDiscount = 0.5,
  });

  final int video5sStandard;
  final int video5sHd;
  final int video5sUltraHd;
  final int video10sStandard;
  final int video10sHd;
  final int video10sUltraHd;
  final int imagePerPhoto;
  final double svipDiscount;

  int _apply(int cost, bool isSvip) =>
      isSvip ? (cost * (1 - svipDiscount)).ceil() : cost;

  // Used by template screens — applies SVIP discount to the template's own cost.
  int calculate({
    required int templateBaseCost,
    required String duration,
    required String quality,
    required bool isSvip,
  }) =>
      _apply(templateBaseCost, isSvip);

  int customVideoCost({
    required String quality,
    required String duration,
    required bool isSvip,
  }) {
    final is10s = duration == '10s';
    final cost = switch (quality) {
      'Ultra HD' => is10s ? video10sUltraHd : video5sUltraHd,
      'High'     => is10s ? video10sHd      : video5sHd,
      _          => is10s ? video10sStandard : video5sStandard,
    };
    return _apply(cost, isSvip);
  }

  int imageGenerationCost({required bool isSvip}) =>
      _apply(imagePerPhoto, isSvip);

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    final video = json['video'] as Map<String, dynamic>?;
    final s5  = video?['5s']  as Map<String, dynamic>?;
    final s10 = video?['10s'] as Map<String, dynamic>?;

    return PricingModel(
      video5sStandard:  (s5?['standard']  as num?)?.toInt() ?? 10,
      video5sHd:        (s5?['hd']        as num?)?.toInt() ?? 20,
      video5sUltraHd:   (s5?['ultra_hd']  as num?)?.toInt() ?? 35,
      video10sStandard: (s10?['standard'] as num?)?.toInt() ?? 15,
      video10sHd:       (s10?['hd']       as num?)?.toInt() ?? 25,
      video10sUltraHd:  (s10?['ultra_hd'] as num?)?.toInt() ?? 40,
      imagePerPhoto:    (json['image_per_photo'] as num?)?.toInt() ?? 150,
      svipDiscount:     (json['svip_discount']   as num?)?.toDouble() ?? 0.5,
    );
  }
}

final pricingProvider = FutureProvider<PricingModel>((ref) async {
  try {
    final data = await ApiService.getPricing();
    return PricingModel.fromJson(data);
  } catch (_) {
    return const PricingModel();
  }
});

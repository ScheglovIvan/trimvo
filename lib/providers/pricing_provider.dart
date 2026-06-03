import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/services/api_service.dart';

class PricingModel {
  const PricingModel({
    this.basePer5s = 5,
    this.basePer10s = 10,
    this.multiplierStandard = 1,
    this.multiplierHd = 2,
    this.multiplierUltraHd = 4,
  });

  final int basePer5s;
  final int basePer10s;
  final int multiplierStandard;
  final int multiplierHd;
  final int multiplierUltraHd;

  int calculate({
    required int templateBaseCost,
    required String duration,
    required String quality,
    required bool isSvip,
  }) {
    final qualityMult = quality == 'Ultra HD'
        ? multiplierUltraHd
        : quality == 'High'
            ? multiplierHd
            : multiplierStandard;
    final durationMult = duration == '10s' ? 2 : 1;
    final cost = templateBaseCost * qualityMult * durationMult;
    return isSvip ? (cost / 2).ceil() : cost;
  }

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    return PricingModel(
      basePer5s: (json['gems_base_per_5s'] as num?)?.toInt() ?? 5,
      basePer10s: (json['gems_base_per_10s'] as num?)?.toInt() ?? 10,
      multiplierStandard: (json['gems_multiplier_standard'] as num?)?.toInt() ?? 1,
      multiplierHd: (json['gems_multiplier_hd'] as num?)?.toInt() ?? 2,
      multiplierUltraHd: (json['gems_multiplier_ultra_hd'] as num?)?.toInt() ?? 4,
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

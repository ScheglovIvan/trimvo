class GemPackageModel {
  const GemPackageModel({
    required this.id,
    required this.gemsAmount,
    required this.bonusGems,
    required this.price,
    required this.currency,
    this.label,
    required this.isPopular,
    this.appleProductId,
    required this.order,
  });

  final String id;
  final int gemsAmount;
  final int bonusGems;
  final double price;
  final String currency;
  final String? label;
  final bool isPopular;
  final String? appleProductId;
  final int order;

  factory GemPackageModel.fromJson(Map<String, dynamic> json) {
    return GemPackageModel(
      id: json['id']?.toString() ?? '',
      gemsAmount: (json['gems_amount'] as num?)?.toInt() ?? 0,
      bonusGems: (json['bonus_gems'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'USD',
      label: json['label']?.toString(),
      isPopular: json['is_popular'] as bool? ?? false,
      appleProductId: json['apple_product_id']?.toString(),
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

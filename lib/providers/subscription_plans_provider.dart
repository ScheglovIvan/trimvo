import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/services/api_service.dart';

class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.tier,
    required this.period,
    required this.priceDisplay,
    required this.billingInfo,
    required this.gemsBonus,
    this.badgeText,
    this.isPopular = false,
    this.appleProductId,
  });

  final String id;
  final String name;       // "Weekly VIP", "Yearly VIP", etc.
  final String tier;       // "vip" | "svip"
  final String period;     // "weekly" | "yearly" | "lifetime"
  final String priceDisplay;
  final String billingInfo;
  final int gemsBonus;
  final String? badgeText;
  final bool isPopular;
  final String? appleProductId;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> j) {
    final tier = (j['tier'] ?? j['plan_type'] ?? 'vip').toString().toLowerCase();
    final period = (j['period'] ?? j['billing_period'] ?? 'weekly').toString().toLowerCase();
    final name = j['name']?.toString() ??
        j['title']?.toString() ??
        '${_cap(period)} ${tier.toUpperCase()}';

    final rawPrice = j['price'] ?? j['price_amount'] ?? j['amount'];
    final currency = j['currency']?.toString() ?? '';
    final priceDisplay = j['price_display']?.toString() ??
        j['price_formatted']?.toString() ??
        (rawPrice != null
            ? (currency.isNotEmpty ? '$rawPrice $currency' : '$rawPrice')
            : '—');

    final billingInfo = j['billing_info']?.toString() ??
        j['billing_description']?.toString() ??
        (period == 'lifetime' ? 'Pay once, enjoy forever' : '$priceDisplay · Billed $period');

    final gems = (j['gems_bonus'] ?? j['gems_included'] ?? j['gems'] ?? 0) as num;
    final badge = j['badge']?.toString() ?? j['label']?.toString() ?? j['badge_text']?.toString();
    final popular = j['is_popular'] == true || j['popular'] == true;

    return SubscriptionPlanModel(
      id: j['id']?.toString() ?? '',
      name: name,
      tier: tier,
      period: period,
      priceDisplay: priceDisplay,
      billingInfo: billingInfo,
      gemsBonus: gems.toInt(),
      badgeText: (badge != null && badge.isNotEmpty) ? badge : null,
      isPopular: popular,
      appleProductId: j['apple_product_id']?.toString() ?? j['product_id']?.toString(),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  final raw = await ApiService.getSubscriptionPlans();
  return raw.map(SubscriptionPlanModel.fromJson).toList();
});

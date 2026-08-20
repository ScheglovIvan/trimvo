import 'package:flutter_test/flutter_test.dart';
import 'package:trimvo/providers/subscription_plans_provider.dart';

SubscriptionPlanModel plan(String tier, String period, String productId) =>
    SubscriptionPlanModel(
      id: '$tier-$period',
      name: '${period[0].toUpperCase()}${period.substring(1)} '
          '${tier.toUpperCase()}',
      tier: tier,
      period: period,
      priceDisplay: '0',
      billingInfo: '',
      gemsBonus: 0,
      appleProductId: productId,
    );

void main() {
  // Mirrors the real backend payload that triggered the App Review rejection:
  // SVIP has lifetime + weekly, and the API returns weekly FIRST.
  final apiPlans = [
    plan('svip', 'weekly', 'com.batteam.trimvo.svip.weekly'),
    plan('svip', 'lifetime', 'com.batteam.trimvo.svip.lifetime'),
    plan('vip', 'weekly', 'com.batteam.trimvo.vip.weekly'),
    plan('vip', 'yearly', 'com.batteam.trimvo.vip.yearly'),
  ];

  group('resolvePlanFor', () {
    test('lifetime SVIP resolves to the lifetime product, not weekly', () {
      final resolved = resolvePlanFor(apiPlans, 'svip', 'lifetime');
      expect(resolved!.appleProductId, 'com.batteam.trimvo.svip.lifetime');
      expect(resolved.period, 'lifetime');
    });

    test('weekly SVIP resolves to the weekly product', () {
      final resolved = resolvePlanFor(apiPlans, 'svip', 'weekly');
      expect(resolved!.appleProductId, 'com.batteam.trimvo.svip.weekly');
    });

    test('yearly VIP resolves to the yearly product', () {
      final resolved = resolvePlanFor(apiPlans, 'vip', 'yearly');
      expect(resolved!.appleProductId, 'com.batteam.trimvo.vip.yearly');
    });

    test('never crosses tiers', () {
      for (final period in ['lifetime', 'yearly', 'weekly']) {
        expect(resolvePlanFor(apiPlans, 'vip', period)!.tier, 'vip');
        expect(resolvePlanFor(apiPlans, 'svip', period)!.tier, 'svip');
      }
    });

    test('missing period falls back to the first rendered card', () {
      // SVIP has no yearly plan; the first card is lifetime.
      final resolved = resolvePlanFor(apiPlans, 'svip', 'yearly');
      expect(resolved!.period, 'lifetime');
      expect(resolved.appleProductId, 'com.batteam.trimvo.svip.lifetime');
    });

    test('an unfamiliar period buys that period, not weekly', () {
      // A period the app has no hardcoded card for must still resolve to its
      // own product rather than silently falling through to the weekly one.
      final withMonthly = [
        ...apiPlans,
        plan('vip', 'monthly', 'com.batteam.trimvo.vip.monthly'),
      ];
      final resolved = resolvePlanFor(withMonthly, 'vip', 'monthly');
      expect(resolved!.appleProductId, 'com.batteam.trimvo.vip.monthly');
      expect(resolved.period, 'monthly');
    });

    test('returns null when the tier has no plans', () {
      expect(resolvePlanFor(const [], 'svip', 'weekly'), isNull);
      expect(resolvePlanFor([plan('vip', 'weekly', 'x')], 'svip', 'weekly'),
          isNull);
    });

    test('resolved plan is always the first card when fallback applies', () {
      final tierPlans = plansForTier(apiPlans, 'svip');
      expect(resolvePlanFor(apiPlans, 'svip', 'yearly'), tierPlans.first);
    });
  });

  group('plansForTier', () {
    test('orders lifetime > yearly > weekly regardless of API order', () {
      expect(
        plansForTier(apiPlans, 'svip').map((p) => p.period),
        ['lifetime', 'weekly'],
      );
      expect(
        plansForTier(apiPlans, 'vip').map((p) => p.period),
        ['yearly', 'weekly'],
      );
    });

    test('unknown periods sort last instead of first', () {
      final withMonthly = [
        plan('vip', 'monthly', 'm'),
        ...apiPlans,
      ];
      expect(
        plansForTier(withMonthly, 'vip').map((p) => p.period),
        ['yearly', 'weekly', 'monthly'],
      );
    });
  });

  group('SubscriptionPlanModel.fromJson', () {
    test('reads lifetime period and apple product id', () {
      final model = SubscriptionPlanModel.fromJson({
        'id': '1',
        'tier': 'svip',
        'period': 'Lifetime',
        'apple_product_id': 'com.batteam.trimvo.svip.lifetime',
        'price_display': '83.99 USD',
      });
      expect(model.period, 'lifetime');
      expect(model.appleProductId, 'com.batteam.trimvo.svip.lifetime');
      expect(model.billingInfo, 'Pay once, enjoy forever');
    });
  });
}

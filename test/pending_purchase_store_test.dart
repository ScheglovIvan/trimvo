import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trimvo/services/pending_purchase_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  PendingPurchase sample({String key = 'tx-1', String backendId = 'plan-1'}) =>
      PendingPurchase(
        key: key,
        kind: 'subscription',
        productId: 'com.batteam.trimvo.svip.weekly',
        backendId: backendId,
        jws: 'receipt-data',
      );

  group('pending deliveries', () {
    test('starts empty', () async {
      expect(await PendingPurchaseStore.load(), isEmpty);
    });

    test('survives a round trip', () async {
      await PendingPurchaseStore.add(sample());
      final loaded = await PendingPurchaseStore.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.key, 'tx-1');
      expect(loaded.single.jws, 'receipt-data');
      expect(loaded.single.backendId, 'plan-1');
      expect(loaded.single.isSubscription, isTrue);
      expect(loaded.single.attempts, 0);
    });

    test('add is idempotent on key — no duplicate deliveries', () async {
      await PendingPurchaseStore.add(sample());
      await PendingPurchaseStore.add(sample(backendId: 'plan-2'));
      final loaded = await PendingPurchaseStore.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.backendId, 'plan-2');
    });

    test('remove clears the entry', () async {
      await PendingPurchaseStore.add(sample());
      await PendingPurchaseStore.remove('tx-1');
      expect(await PendingPurchaseStore.load(), isEmpty);
    });

    test('remove of an unknown key is a no-op', () async {
      await PendingPurchaseStore.add(sample());
      await PendingPurchaseStore.remove('nope');
      expect(await PendingPurchaseStore.load(), hasLength(1));
    });

    test('replace bumps the attempt counter in place', () async {
      await PendingPurchaseStore.add(sample());
      var item = (await PendingPurchaseStore.load()).single;
      for (var i = 0; i < 3; i++) {
        item = item.withAttempt();
        await PendingPurchaseStore.replace(item);
      }
      final loaded = await PendingPurchaseStore.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.attempts, 3);
    });

    test('replace of an unknown key does not resurrect it', () async {
      await PendingPurchaseStore.replace(sample(key: 'ghost'));
      expect(await PendingPurchaseStore.load(), isEmpty);
    });

    test('multiple purchases queue independently', () async {
      await PendingPurchaseStore.add(sample(key: 'a'));
      await PendingPurchaseStore.add(sample(key: 'b'));
      expect((await PendingPurchaseStore.load()).map((e) => e.key), ['a', 'b']);
    });

    test('corrupt storage degrades to empty instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'iap_pending_deliveries_v1': 'not json at all',
      });
      expect(await PendingPurchaseStore.load(), isEmpty);
    });

    test('entries without a receipt are dropped on load', () async {
      SharedPreferences.setMockInitialValues({
        'iap_pending_deliveries_v1':
            '[{"key":"a","kind":"gems","product_id":"p","backend_id":"b","jws":""}]',
      });
      expect(await PendingPurchaseStore.load(), isEmpty);
    });
  });

  group('product mapping', () {
    test('survives a cold start so a late transaction still resolves',
        () async {
      await PendingPurchaseStore.rememberProduct(
        'com.batteam.trimvo.svip.lifetime',
        kind: 'subscription',
        backendId: 'plan-lifetime',
      );
      final found = await PendingPurchaseStore.lookupProduct(
        'com.batteam.trimvo.svip.lifetime',
      );
      expect(found!.kind, 'subscription');
      expect(found.backendId, 'plan-lifetime');
    });

    test('unknown product returns null', () async {
      expect(await PendingPurchaseStore.lookupProduct('nope'), isNull);
      expect(await PendingPurchaseStore.lookupProduct(''), isNull);
    });

    test('later purchase of the same product overwrites the mapping', () async {
      await PendingPurchaseStore.rememberProduct('p',
          kind: 'gems', backendId: 'pack-1');
      await PendingPurchaseStore.rememberProduct('p',
          kind: 'gems', backendId: 'pack-2');
      expect((await PendingPurchaseStore.lookupProduct('p'))!.backendId,
          'pack-2');
    });

    test('gem and subscription products coexist', () async {
      await PendingPurchaseStore.rememberProduct('gem',
          kind: 'gems', backendId: 'pack-1');
      await PendingPurchaseStore.rememberProduct('sub',
          kind: 'subscription', backendId: 'plan-1');
      expect((await PendingPurchaseStore.lookupProduct('gem'))!.kind, 'gems');
      expect((await PendingPurchaseStore.lookupProduct('sub'))!.kind,
          'subscription');
    });
  });
}

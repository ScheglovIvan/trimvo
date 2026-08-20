import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trimvo/providers/iap_provider.dart';
import 'package:trimvo/providers/subscription_plans_provider.dart';
import 'package:trimvo/services/api_service.dart';
import 'package:trimvo/services/pending_purchase_store.dart';

const _productId = 'com.batteam.trimvo.svip.weekly';
const _planId = 'plan-svip-weekly';

/// Records every plugin call the notifier makes and lets a test push
/// PurchaseDetails through the stream exactly like StoreKit would.
class FakeIap extends InAppPurchasePlatform {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();

  final List<String> completed = [];
  final List<String> boughtNonConsumable = [];
  final List<String> boughtConsumable = [];
  int restoreCalls = 0;
  bool available = true;
  Set<String> knownProducts = const {_productId};
  Object? addPaymentError;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);
  Future<void> dispose() => _controller.close();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    final found = ids.where(knownProducts.contains).toList();
    return ProductDetailsResponse(
      productDetails: [
        for (final id in found)
          ProductDetails(
            id: id,
            title: id,
            description: id,
            price: '11.99',
            rawPrice: 11.99,
            currencyCode: 'USD',
          ),
      ],
      notFoundIDs: ids.where((id) => !knownProducts.contains(id)).toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    if (addPaymentError != null) throw addPaymentError!;
    boughtNonConsumable.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    if (addPaymentError != null) throw addPaymentError!;
    boughtConsumable.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.productID);
    purchase.pendingCompletePurchase = false;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
  }
}

/// Stands in for the real SKPaymentQueue.
class FakeQueue implements StoreKitQueue {
  FakeQueue([this.pending = const []]);

  List<SKPaymentTransactionWrapper> pending;
  final List<String> finished = [];
  String receipt = 'receipt-from-queue';

  @override
  Future<List<SKPaymentTransactionWrapper>> transactions() async => pending;

  @override
  Future<void> finish(SKPaymentTransactionWrapper transaction) async {
    if (transaction.transactionState ==
        SKPaymentTransactionStateWrapper.purchasing) {
      throw StateError('StoreKit forbids finishing a purchasing transaction');
    }
    finished.add(transaction.payment.productIdentifier);
    pending = pending.where((t) => t != transaction).toList();
  }

  @override
  Future<String> receiptData() async => receipt;
}

SKPaymentTransactionWrapper stuckTx({
  String productId = _productId,
  String? id = 'stale-tx',
  SKPaymentTransactionStateWrapper state =
      SKPaymentTransactionStateWrapper.purchased,
}) {
  return SKPaymentTransactionWrapper(
    payment: SKPaymentWrapper(productIdentifier: productId),
    transactionState: state,
    transactionIdentifier: id,
  );
}

PurchaseDetails purchased({
  String productId = _productId,
  String id = 'tx-1',
  String receipt = 'receipt-1',
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  return PurchaseDetails(
    purchaseID: id,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: receipt,
      serverVerificationData: receipt,
      source: 'app_store',
    ),
    transactionDate: '0',
    status: status,
  )..pendingCompletePurchase = true;
}

SubscriptionPlanModel weeklySvip() => const SubscriptionPlanModel(
      id: _planId,
      name: 'Weekly SVIP',
      tier: 'svip',
      period: 'weekly',
      priceDisplay: '11.99 USD',
      billingInfo: '',
      gemsBonus: 600,
      appleProductId: _productId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeIap fake;
  late ProviderContainer container;
  late IapNotifier iap;
  late List<String> requests;
  late FakeQueue queue;

  /// Runs [body] with every ApiService HTTP call answered by [respond].
  Future<T> withApi<T>(
    http.Response Function(http.Request request) respond,
    Future<T> Function() body,
  ) {
    return http.runWithClient(
      body,
      () => MockClient((request) async {
        requests.add(request.url.path);
        return respond(request);
      }),
    );
  }

  http.Response ok([Map<String, dynamic> body = const {}]) =>
      http.Response(jsonEncode(body), 200);
  http.Response status(int code) =>
      http.Response(jsonEncode({'detail': 'nope'}), code);

  setUpAll(() {
    // Touch the facade once so its lazy _getOrCreateInstance() registers a
    // platform now; otherwise the first InAppPurchase.instance call inside a
    // test would overwrite the fake we install below. Pretend to be iOS so it
    // registers StoreKit (synchronous) rather than Billing (opens a channel).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'test-token';
    requests = [];
    fake = FakeIap();
    queue = FakeQueue();
    InAppPurchasePlatform.instance = fake;
    container = ProviderContainer(
      overrides: [
        iapProvider.overrideWith(
          (ref) => IapNotifier(
            ref,
            isIos: true,
            replayGrace: Duration.zero,
            queue: queue,
          ),
        ),
      ],
    );
    iap = container.read(iapProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await fake.dispose();
  });

  /// Emits a purchase and waits for the notifier's async handler to settle.
  Future<void> emitAndSettle(PurchaseDetails details) async {
    fake.emit([details]);
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('the transaction is always finished', () {
    test('on a successful verification', () async {
      await withApi((_) => ok({'new_balance': 600}), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });

      expect(fake.boughtNonConsumable, [_productId]);
      expect(fake.completed, [_productId]);
      expect(await PendingPurchaseStore.load(), isEmpty);
      expect(container.read(iapProvider).lastPurchaseType, 'subscription');
      expect(container.read(iapProvider).error, isNull);
    });

    // The App Review failure: verification failed, the transaction was left in
    // the queue, and every later purchase died with duplicate_product_object.
    test('on a backend 500 — and the receipt stays queued for retry', () async {
      await withApi((_) => status(500), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });

      expect(fake.completed, [_productId],
          reason: 'transaction must be finished even though delivery failed');
      final queued = await PendingPurchaseStore.load();
      expect(queued, hasLength(1));
      expect(queued.single.backendId, _planId);
      expect(queued.single.kind, 'subscription');
    });

    test('on a 401 (expired/absent token) — receipt stays queued', () async {
      await withApi((_) => status(401), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });

      expect(fake.completed, [_productId]);
      expect(await PendingPurchaseStore.load(), hasLength(1));
    });

    test('on a network failure — receipt stays queued', () async {
      await http.runWithClient(() async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      }, () => MockClient((_) => throw const SocketExceptionStub()));

      expect(fake.completed, [_productId]);
      expect(await PendingPurchaseStore.load(), hasLength(1));
    });

    test('on a 400 (invalid receipt) — queue is not left dirty', () async {
      await withApi((_) => status(400), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });

      expect(fake.completed, [_productId]);
      expect(await PendingPurchaseStore.load(), isEmpty);
    });

    test('on a cancelled purchase', () async {
      await withApi((_) => ok(), () async {
        await iap.init();
        await emitAndSettle(
          purchased(status: PurchaseStatus.canceled),
        );
      });

      expect(fake.completed, [_productId]);
      expect(container.read(iapProvider).isLoading, isFalse);
    });

    test('on a failed purchase', () async {
      await withApi((_) => ok(), () async {
        await iap.init();
        await emitAndSettle(purchased(status: PurchaseStatus.error));
      });

      expect(fake.completed, [_productId]);
    });

    test('on a restored purchase', () async {
      await withApi((_) => ok(), () async {
        await iap.init();
        await emitAndSettle(purchased(status: PurchaseStatus.restored));
      });

      expect(fake.completed, [_productId]);
    });

    test('a pending purchase is left alone until it resolves', () async {
      await withApi((_) => ok(), () async {
        await iap.init();
        await emitAndSettle(purchased(status: PurchaseStatus.pending));
      });

      expect(fake.completed, isEmpty);
    });
  });

  group('retry delivery', () {
    test('a queued receipt is delivered on the next launch', () async {
      // Launch 1: backend is down.
      await withApi((_) => status(503), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });
      expect(await PendingPurchaseStore.load(), hasLength(1));

      // Launch 2: backend is back.
      final delivered = await withApi(
        (_) => ok({'new_balance': 600}),
        () => iap.flushPendingDeliveries(),
      );

      expect(delivered, isTrue);
      expect(await PendingPurchaseStore.load(), isEmpty);
      expect(requests.any((p) => p.endsWith('/payments/apple/verify-subscription')),
          isTrue, reason: 'requests were: $requests');
    });

    test('a permanently invalid receipt is dropped, not retried forever',
        () async {
      await withApi((_) => status(500), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });

      final delivered = await withApi(
        (_) => status(404),
        () => iap.flushPendingDeliveries(),
      );

      expect(delivered, isFalse);
      expect(await PendingPurchaseStore.load(), isEmpty);
    });

    test('attempts are capped so the queue cannot grow forever', () async {
      await withApi((_) => status(500), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });

      for (var i = 0; i < PendingPurchaseStore.maxAttempts + 2; i++) {
        await withApi((_) => status(500), () => iap.flushPendingDeliveries());
      }

      expect(await PendingPurchaseStore.load(), isEmpty);
    });

    test('restore also flushes the local queue', () async {
      await withApi((_) => status(500), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await emitAndSettle(purchased());
      });
      expect(await PendingPurchaseStore.load(), hasLength(1));

      await withApi((_) => ok(), () async {
        await iap.restorePurchases();
        await Future<void>.delayed(const Duration(seconds: 5));
      });

      expect(fake.restoreCalls, 1);
      expect(await PendingPurchaseStore.load(), isEmpty);
      expect(container.read(iapProvider).lastPurchaseType, 'restore');
      expect(container.read(iapProvider).isLoading, isFalse);
    });
  });

  group('user-facing errors', () {
    test('a duplicate-transaction crash is never shown raw', () async {
      fake.addPaymentError = const PlatformExceptionStub(
        'storekit_duplicate_product_object',
        'There is a pending transaction for the same product identifier.',
      );

      await withApi((_) => ok(), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
      });

      final error = container.read(iapProvider).error!;
      expect(error, isNot(contains('PlatformException')));
      expect(error, isNot(contains('storekit_duplicate_product_object')));
      expect(error, contains('still being processed'));
      expect(container.read(iapProvider).isLoading, isFalse);
    });

    test('an unknown crash falls back to a plain message', () async {
      fake.addPaymentError = StateError('boom internal detail');

      await withApi((_) => ok(), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
      });

      final error = container.read(iapProvider).error!;
      expect(error, 'Purchase failed. Please try again.');
      expect(error, isNot(contains('boom internal detail')));
    });

    test('a missing product does not start a payment', () async {
      fake.knownProducts = const {};

      await withApi((_) => ok(), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
      });

      expect(fake.boughtNonConsumable, isEmpty);
      expect(container.read(iapProvider).error, isNotNull);
      expect(container.read(iapProvider).isLoading, isFalse);
    });

    test('a store that is unavailable does not start a payment', () async {
      fake.available = false;

      await withApi((_) => ok(), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
      });

      expect(fake.boughtNonConsumable, isEmpty);
      expect(container.read(iapProvider).error,
          'In-app purchases are not available on this device.');
    });

    test('a plan without an apple product id is rejected cleanly', () async {
      await withApi((_) => ok(), () async {
        await iap.init();
        await iap.purchaseSubscription(
          const SubscriptionPlanModel(
            id: 'x',
            name: 'x',
            tier: 'svip',
            period: 'weekly',
            priceDisplay: '',
            billingInfo: '',
            gemsBonus: 0,
          ),
        );
      });

      expect(fake.boughtNonConsumable, isEmpty);
      expect(container.read(iapProvider).error,
          'This plan is not available right now.');
    });
  });

  // This is the mechanism that produced the App Review rejection: a leftover
  // unfinished transaction makes the plugin refuse the next addPayment with
  // `storekit_duplicate_product_object`.
  group('stale StoreKit transactions', () {
    test('a leftover transaction is cleared before buying again', () async {
      queue.pending = [stuckTx()];

      await withApi((_) => ok(), () async {
        await iap.init();
      });

      expect(queue.finished, [_productId]);
      expect(queue.pending, isEmpty);
    });

    test('its receipt is captured, not thrown away', () async {
      // The mapping survives from the session that started the purchase.
      await PendingPurchaseStore.rememberProduct(
        _productId,
        kind: 'subscription',
        backendId: _planId,
      );
      queue.pending = [stuckTx()];
      queue.receipt = 'receipt-recovered';

      // Delivery fails so we can inspect what got queued.
      await withApi((_) => status(500), () async {
        await iap.init();
      });

      final queued = await PendingPurchaseStore.load();
      expect(queued, hasLength(1));
      expect(queued.single.jws, 'receipt-recovered');
      expect(queued.single.backendId, _planId);
    });

    test('a recovered receipt is delivered on the spot when the API is up',
        () async {
      await PendingPurchaseStore.rememberProduct(
        _productId,
        kind: 'subscription',
        backendId: _planId,
      );
      queue.pending = [stuckTx()];

      await withApi((_) => ok(), () async {
        await iap.init();
      });

      expect(queue.finished, [_productId]);
      expect(await PendingPurchaseStore.load(), isEmpty);
      expect(requests.any((p) => p.endsWith('/payments/apple/verify-subscription')),
          isTrue, reason: 'requests were: $requests');
    });

    test('an Ask-to-Buy (deferred) transaction is never cancelled', () async {
      queue.pending = [
        stuckTx(state: SKPaymentTransactionStateWrapper.deferred),
      ];

      await withApi((_) => ok(), () async {
        await iap.init();
        await iap.purchaseSubscription(weeklySvip());
      });

      expect(queue.finished, isEmpty,
          reason: 'finishing a deferred tx silently kills a pending purchase');
      expect(queue.pending, hasLength(1));
    });

    test('a receipt rescued at buy time is delivered immediately', () async {
      await PendingPurchaseStore.rememberProduct(
        _productId,
        kind: 'subscription',
        backendId: _planId,
      );

      await withApi((_) => ok(), () async {
        await iap.init();
        // Something landed in the queue after boot — e.g. a purchase completed
        // while the app was backgrounded.
        queue.pending = [stuckTx(id: 'late-tx')];
        requests.clear();
        await iap.purchaseSubscription(weeklySvip());
      });

      expect(queue.finished, [_productId]);
      expect(await PendingPurchaseStore.load(), isEmpty,
          reason: 'the rescued receipt should not wait for the next launch');
      expect(requests.any((p) => p.endsWith('/payments/apple/verify-subscription')),
          isTrue, reason: 'requests were: $requests');
      expect(fake.boughtNonConsumable, [_productId]);
    });

    test('a purchasing transaction is left alone — StoreKit forbids it',
        () async {
      queue.pending = [
        stuckTx(state: SKPaymentTransactionStateWrapper.purchasing),
      ];

      await withApi((_) => ok(), () async {
        await iap.init();
      });

      expect(queue.finished, isEmpty);
      expect(queue.pending, hasLength(1));
    });

    test('a failed transaction is cleared without inventing a delivery',
        () async {
      queue.pending = [
        stuckTx(state: SKPaymentTransactionStateWrapper.failed),
      ];

      await withApi((_) => ok(), () async {
        await iap.init();
      });

      expect(queue.finished, [_productId]);
      expect(await PendingPurchaseStore.load(), isEmpty);
      expect(requests, isEmpty);
    });

    test('buying sweeps only the product being bought', () async {
      queue.pending = [
        stuckTx(productId: 'com.batteam.trimvo.gems.starter', id: 'other'),
      ];

      await withApi((_) => ok(), () async {
        await iap.init();
        expect(queue.finished, ['com.batteam.trimvo.gems.starter'],
            reason: 'init sweeps everything');

        queue.finished.clear();
        queue.pending = [
          stuckTx(productId: 'com.batteam.trimvo.gems.starter', id: 'other'),
          stuckTx(),
        ];
        await iap.purchaseSubscription(weeklySvip());
      });

      expect(queue.finished, [_productId]);
      expect(fake.boughtNonConsumable, [_productId]);
    });

    test('a purchase started during boot waits for the startup sweep',
        () async {
      queue.pending = [stuckTx()];

      await withApi((_) => ok(), () async {
        // No await on init(): exactly what the splash screen does.
        final booting = iap.init();
        await iap.purchaseSubscription(weeklySvip());
        await booting;
      });

      // Swept once, not twice — the buy waited instead of racing the sweep.
      expect(queue.finished, [_productId]);
      expect(fake.boughtNonConsumable, [_productId]);
    });

    test('init only ever attaches one listener', () async {
      await withApi((_) => ok(), () async {
        await Future.wait([iap.init(), iap.init(), iap.init()]);
        await emitAndSettle(purchased());
      });

      // A second listener would deliver (and complete) the same purchase twice.
      expect(fake.completed, [_productId]);
      expect(
          requests
              .where((p) => p.endsWith('/payments/apple/verify-subscription'))
              .length,
          lessThanOrEqualTo(1));
    });

    test('a broken queue never blocks the purchase', () async {
      await withApi((_) => ok(), () async {
        await iap.init();
        queue.pending = [stuckTx(state: SKPaymentTransactionStateWrapper.purchasing)];
        await iap.purchaseSubscription(weeklySvip());
      });

      // The sweep could not finish the transaction, but we still attempt the
      // purchase and surface a friendly message if StoreKit refuses it.
      expect(fake.boughtNonConsumable, [_productId]);
    });
  });

  group('double tap', () {
    test('a second tap while a purchase is in flight is ignored', () async {
      await withApi((_) => ok(), () async {
        await iap.init();
        await Future.wait([
          iap.purchaseSubscription(weeklySvip()),
          iap.purchaseSubscription(weeklySvip()),
        ]);
      });

      expect(fake.boughtNonConsumable, hasLength(1));
    });
  });
}

class PlatformExceptionStub implements Exception {
  const PlatformExceptionStub(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'PlatformException($code, $message, null, null)';
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: Failed host lookup';
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:trimvo/models/gem_package_model.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:trimvo/providers/subscription_plans_provider.dart';
import 'package:trimvo/services/api_service.dart';
import 'package:trimvo/services/pending_purchase_store.dart';

const Object _kUnset = Object();

/// Thin seam over the raw `SKPaymentQueue`.
///
/// The plugin refuses `addPayment` while StoreKit still holds an unfinished
/// transaction for the same product (`storekit_duplicate_product_object`), so
/// the queue has to be swept before every purchase. Kept behind an interface so
/// that sweep is testable without the StoreKit pigeon channel.
abstract class StoreKitQueue {
  Future<List<SKPaymentTransactionWrapper>> transactions();
  Future<void> finish(SKPaymentTransactionWrapper transaction);

  /// Base64 app receipt — the same payload the purchase stream exposes as
  /// `serverVerificationData` under StoreKit 1.
  Future<String> receiptData();
}

class _LiveStoreKitQueue implements StoreKitQueue {
  const _LiveStoreKitQueue();

  @override
  Future<List<SKPaymentTransactionWrapper>> transactions() =>
      SKPaymentQueueWrapper().transactions();

  @override
  Future<void> finish(SKPaymentTransactionWrapper transaction) =>
      SKPaymentQueueWrapper().finishTransaction(transaction);

  @override
  Future<String> receiptData() => SKReceiptManager.retrieveReceiptData();
}

const String _kGems = 'gems';
const String _kSubscription = 'subscription';

class IapState {
  const IapState({
    this.isLoading = false,
    this.error,
    this.lastPurchaseType,
  });

  final bool isLoading;
  final String? error;
  // 'gems' | 'subscription' | 'restore'
  final String? lastPurchaseType;

  IapState copyWith({
    bool? isLoading,
    Object? error = _kUnset,
    Object? lastPurchaseType = _kUnset,
  }) {
    return IapState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _kUnset) ? this.error : error as String?,
      lastPurchaseType: identical(lastPurchaseType, _kUnset)
          ? this.lastPurchaseType
          : lastPurchaseType as String?,
    );
  }
}

class IapNotifier extends StateNotifier<IapState> {
  IapNotifier(
    this._ref, {
    @visibleForTesting bool? isIos,
    @visibleForTesting Duration replayGrace = const Duration(milliseconds: 800),
    @visibleForTesting StoreKitQueue queue = const _LiveStoreKitQueue(),
  })  : _isIos = isIos ?? Platform.isIOS,
        _replayGrace = replayGrace,
        _queue = queue,
        super(const IapState());

  final Ref _ref;

  /// StoreKit-only feature. Overridable so the flow can be tested off-device.
  final bool _isIos;

  /// How long to let StoreKit replay unfinished transactions into the freshly
  /// attached listener before we sweep the queue ourselves.
  final Duration _replayGrace;

  final StoreKitQueue _queue;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Future<void>? _initFuture;
  bool _buyInFlight = false;

  // restore state
  bool _isRestoring = false;
  final List<String> _restoredJws = [];
  Timer? _restoreTimer;

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _restoreTimer?.cancel();
    super.dispose();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Attaches the StoreKit listener and drains anything left over from a
  /// previous session. Must run at app start (after auth is loaded), not when
  /// the paywall opens — an unfinished transaction blocks all later purchases.
  Future<void> init() {
    if (!_isIos) return Future<void>.value();
    // Cached so a purchase started while the app is still booting waits for the
    // startup sweep instead of racing it on the same transactions.
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchasesUpdated,
      onError: (Object error) {
        debugPrint('[IAP] stream error: $error');
        if (mounted) {
          state = state.copyWith(error: _friendlyError(error), isLoading: false);
        }
      },
    );

    // Give StoreKit a moment to replay unfinished transactions to the listener
    // we just attached, then clean up whatever it did not replay.
    await Future<void>.delayed(_replayGrace);
    await _drainStoreKitQueue();
    await flushPendingDeliveries();
  }

  Future<void> purchaseGemPackage(GemPackageModel package) async {
    await _startPurchase(
      kind: _kGems,
      backendId: package.id,
      productId: package.appleProductId,
      unavailableMessage: 'This package is not available right now.',
    );
  }

  Future<void> purchaseSubscription(SubscriptionPlanModel plan) async {
    await _startPurchase(
      kind: _kSubscription,
      backendId: plan.id,
      productId: plan.appleProductId,
      unavailableMessage: 'This plan is not available right now.',
    );
  }

  Future<void> restorePurchases() async {
    if (!_isIos) return;

    await init();

    if (mounted) {
      state = state.copyWith(isLoading: true, error: null, lastPurchaseType: null);
    }
    _isRestoring = true;
    _restoredJws.clear();

    // Deliver anything still queued locally before asking StoreKit for more.
    await flushPendingDeliveries();

    // Timer fires when no new restored transactions arrive for 4 seconds.
    _scheduleRestoreFinalize();

    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _isRestoring = false;
      _restoreTimer?.cancel();
      if (mounted) {
        state = state.copyWith(error: _friendlyError(e), isLoading: false);
      }
    }
  }

  void clearError() {
    if (mounted) state = state.copyWith(error: null);
  }

  void clearLastPurchase() {
    if (mounted) state = state.copyWith(lastPurchaseType: null);
  }

  // ── Purchase flow ───────────────────────────────────────────────────────────

  Future<void> _startPurchase({
    required String kind,
    required String backendId,
    required String? productId,
    required String unavailableMessage,
  }) async {
    if (!_isIos) return;

    debugPrint('[IAP] buy $kind: backendId=$backendId product=$productId');
    if (productId == null || productId.isEmpty) {
      if (mounted) {
        state = state.copyWith(error: unavailableMessage, isLoading: false);
      }
      return;
    }

    if (_buyInFlight) {
      debugPrint('[IAP] buy ignored — another purchase is in flight');
      return;
    }
    _buyInFlight = true;

    if (mounted) {
      state = state.copyWith(isLoading: true, error: null, lastPurchaseType: null);
    }

    try {
      await init();

      if (!await InAppPurchase.instance.isAvailable()) {
        _fail('In-app purchases are not available on this device.');
        return;
      }

      final response = await InAppPurchase.instance.queryProductDetails({productId});
      debugPrint('[IAP] found=${response.productDetails.length} '
          'notFound=${response.notFoundIDs}');
      if (response.productDetails.isEmpty) {
        _fail(unavailableMessage);
        return;
      }

      // Persisted so a transaction that only lands after a restart can still be
      // matched to the right backend product.
      await PendingPurchaseStore.rememberProduct(
        productId,
        kind: kind,
        backendId: backendId,
      );

      // Clear anything StoreKit still holds for this product, otherwise
      // addPayment fails with storekit_duplicate_product_object.
      await _releaseTransactionsFor(productId);

      final param = PurchaseParam(productDetails: response.productDetails.first);
      if (kind == _kGems) {
        await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      } else {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      debugPrint('[IAP] buy failed: $e');
      _fail(_friendlyError(e));
    } finally {
      _buyInFlight = false;
    }
  }

  void _fail(String message) {
    if (mounted) state = state.copyWith(error: message, isLoading: false);
  }

  // ── StoreKit queue hygiene ──────────────────────────────────────────────────

  /// Finishes every transaction StoreKit still holds for [productId], first
  /// capturing any value so a purchase is never dropped silently.
  Future<void> _releaseTransactionsFor(String productId) async {
    final captured = await _drainStoreKitQueue(productId: productId);
    // Something was rescued from the queue — hand it to the backend now rather
    // than making the user wait for the next launch.
    if (captured > 0) await flushPendingDeliveries();
  }

  /// Returns how many receipts were parked in the local delivery queue.
  Future<int> _drainStoreKitQueue({String? productId}) async {
    if (!_isIos) return 0;

    var captured = 0;
    try {
      final transactions = await _queue.transactions();
      if (transactions.isEmpty) return 0;

      var finished = 0;
      for (final tx in transactions) {
        final txProduct = tx.payment.productIdentifier;
        if (productId != null && txProduct != productId) continue;
        // StoreKit forbids finishing a transaction that is still purchasing.
        if (tx.transactionState == SKPaymentTransactionStateWrapper.purchasing) {
          continue;
        }
        // Ask to Buy: the purchase is waiting for a parent's approval. Finishing
        // it here would silently cancel a purchase the user is still expecting.
        if (tx.transactionState == SKPaymentTransactionStateWrapper.deferred) {
          debugPrint('[IAP] leaving deferred tx $txProduct for approval');
          continue;
        }

        if (tx.transactionState == SKPaymentTransactionStateWrapper.purchased ||
            tx.transactionState == SKPaymentTransactionStateWrapper.restored) {
          if (await _capturePendingDelivery(
            productId: txProduct,
            transactionId: tx.transactionIdentifier,
          )) {
            captured++;
          }
        }

        debugPrint('[IAP] finishing stale tx $txProduct '
            'state=${tx.transactionState}');
        await _queue.finish(tx);
        finished++;
      }

      if (finished > 0) {
        // SKPaymentQueue removes finished transactions asynchronously; give the
        // observer a beat before a new addPayment for the same product.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('[IAP] queue drain failed: $e');
    }
    return captured;
  }

  /// Stores the app receipt for a transaction we are about to finish without
  /// having verified it, so [flushPendingDeliveries] can deliver it later.
  Future<bool> _capturePendingDelivery({
    required String productId,
    required String? transactionId,
  }) async {
    try {
      final jws = await _queue.receiptData();
      if (jws.isEmpty) return false;

      final mapping = await PendingPurchaseStore.lookupProduct(productId);
      await PendingPurchaseStore.add(
        PendingPurchase(
          key: transactionId ?? '$productId:orphan',
          kind: mapping?.kind ?? _kGems,
          productId: productId,
          backendId: mapping?.backendId ?? '',
          jws: jws,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[IAP] capture pending failed: $e');
      return false;
    }
  }

  // ── Purchase stream ─────────────────────────────────────────────────────────

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    debugPrint('[IAP] ${purchase.productID} status=${purchase.status}');

    switch (purchase.status) {
      case PurchaseStatus.pending:
        return;

      case PurchaseStatus.canceled:
        await _complete(purchase);
        if (mounted) state = state.copyWith(isLoading: false);
        return;

      case PurchaseStatus.error:
        await _complete(purchase);
        final code = purchase.error?.code ?? '';
        if (code == 'SKErrorPaymentCancelled' || code == 'user_cancelled') {
          if (mounted) state = state.copyWith(isLoading: false);
        } else {
          _fail(_friendlyError(purchase.error));
        }
        return;

      case PurchaseStatus.restored:
        final jws = purchase.verificationData.serverVerificationData;
        if (jws.isNotEmpty) _restoredJws.add(jws);
        await _complete(purchase);
        if (_isRestoring) _scheduleRestoreFinalize();
        return;

      case PurchaseStatus.purchased:
        await _deliverPurchase(purchase);
        return;
    }
  }

  /// Always finishes the StoreKit transaction — first parking the receipt in the
  /// local queue, then attempting immediate delivery. Leaving a transaction
  /// unfinished would block every future purchase of the same product.
  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final jws = purchase.verificationData.serverVerificationData;
    final mapping = await PendingPurchaseStore.lookupProduct(productId);

    final pending = PendingPurchase(
      key: purchase.purchaseID ?? '$productId:${purchase.transactionDate ?? ''}',
      kind: mapping?.kind ?? _kGems,
      productId: productId,
      backendId: mapping?.backendId ?? '',
      jws: jws,
    );

    if (jws.isNotEmpty) await PendingPurchaseStore.add(pending);
    await _complete(purchase);

    if (jws.isEmpty || pending.backendId.isEmpty) {
      debugPrint('[IAP] cannot deliver $productId — jws/mapping missing');
      _fail('We could not confirm this purchase. Tap Restore to try again.');
      return;
    }

    final result = await _deliver(pending);
    switch (result) {
      case _DeliveryResult.delivered:
        await PendingPurchaseStore.remove(pending.key);
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            lastPurchaseType: pending.isSubscription ? _kSubscription : _kGems,
          );
        }
      case _DeliveryResult.permanentlyFailed:
        await PendingPurchaseStore.remove(pending.key);
        _fail('This purchase could not be validated. '
            'If you were charged, tap Restore.');
      case _DeliveryResult.retryLater:
        _fail('Purchase received — we are still activating it. '
            'It will be applied automatically, or tap Restore.');
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    try {
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    } catch (e) {
      debugPrint('[IAP] completePurchase failed: $e');
    }
  }

  // ── Local delivery queue ────────────────────────────────────────────────────

  /// Retries every purchase that StoreKit already finished but the backend has
  /// not acknowledged yet. Safe to call repeatedly.
  Future<bool> flushPendingDeliveries() async {
    final items = await PendingPurchaseStore.load();
    if (items.isEmpty) return false;

    debugPrint('[IAP] flushing ${items.length} pending delivery(ies)');
    var anyDelivered = false;

    for (final item in items) {
      if (item.backendId.isEmpty) {
        // Nothing to point the backend at — restore is the only recovery path.
        await PendingPurchaseStore.remove(item.key);
        continue;
      }

      final result = await _deliver(item);
      switch (result) {
        case _DeliveryResult.delivered:
          await PendingPurchaseStore.remove(item.key);
          anyDelivered = true;
        case _DeliveryResult.permanentlyFailed:
          await PendingPurchaseStore.remove(item.key);
        case _DeliveryResult.retryLater:
          final next = item.withAttempt();
          if (next.attempts >= PendingPurchaseStore.maxAttempts) {
            await PendingPurchaseStore.remove(item.key);
          } else {
            await PendingPurchaseStore.replace(next);
          }
      }
    }

    return anyDelivered;
  }

  Future<_DeliveryResult> _deliver(PendingPurchase item) async {
    try {
      if (item.isSubscription) {
        await ApiService.verifyAppleSubscription(
          jwsRepresentation: item.jws,
          planId: item.backendId,
        );
        // A subscription also moves the tier, so re-read the whole profile.
        await _refreshBalance();
      } else {
        final result = await ApiService.verifyApplePurchase(
          jwsRepresentation: item.jws,
          packageId: item.backendId,
        );
        final newBalance = (result['new_balance'] as num?)?.toInt();
        if (newBalance != null) {
          _ref.read(authProvider.notifier).updateGems(newBalance);
        } else {
          await _refreshBalance();
        }
      }
      return _DeliveryResult.delivered;
    } on ApiException catch (e) {
      debugPrint('[IAP] deliver ${item.productId} failed: ${e.statusCode} ${e.message}');
      // 400/404 — receipt is invalid or already consumed: nothing to retry.
      // 401/409/5xx and everything else stay queued for a later attempt.
      if (e.statusCode == 400 || e.statusCode == 404) {
        return _DeliveryResult.permanentlyFailed;
      }
      return _DeliveryResult.retryLater;
    } catch (e) {
      debugPrint('[IAP] deliver ${item.productId} error: $e');
      return _DeliveryResult.retryLater;
    }
  }

  Future<void> _refreshBalance() async {
    try {
      await _ref.read(authProvider.notifier).refreshBalance();
    } catch (_) {}
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  void _scheduleRestoreFinalize() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 4), _finalizeRestore);
  }

  Future<void> _finalizeRestore() async {
    _isRestoring = false;

    if (_restoredJws.isEmpty) {
      // Nothing came back from StoreKit, but a locally queued purchase may
      // still be deliverable.
      await flushPendingDeliveries();
      if (mounted) {
        state = state.copyWith(isLoading: false, lastPurchaseType: 'restore');
      }
      return;
    }

    try {
      await ApiService.restoreApplePurchases(jwsRepresentations: _restoredJws);
    } catch (e) {
      debugPrint('[IAP] restore backend error: $e');
    }

    await flushPendingDeliveries();
    await _refreshBalance();

    if (mounted) {
      state = state.copyWith(isLoading: false, lastPurchaseType: 'restore');
    }
  }

  // ── Errors ──────────────────────────────────────────────────────────────────

  /// Never surface a raw PlatformException to the user — App Review flags it.
  String _friendlyError(Object? error) {
    if (error == null) return 'Purchase failed. Please try again.';

    final text = error is IAPError
        ? '${error.code} ${error.message}'
        : error.toString();

    if (text.contains('storekit_duplicate_product_object')) {
      return 'A previous purchase is still being processed. '
          'Please try again in a moment.';
    }
    if (text.contains('SKErrorPaymentCancelled') ||
        text.contains('user_cancelled')) {
      return 'Purchase cancelled.';
    }
    if (text.contains('SKErrorPaymentNotAllowed')) {
      return 'Purchases are not allowed on this device. '
          'Check Screen Time restrictions.';
    }
    if (text.contains('SKErrorStoreProductNotAvailable') ||
        text.contains('storekit_invalid_payment')) {
      return 'This product is not available in your region.';
    }
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('TimeoutException')) {
      return 'No connection to the App Store. Please check your network.';
    }
    return 'Purchase failed. Please try again.';
  }
}

enum _DeliveryResult { delivered, permanentlyFailed, retryLater }

final iapProvider = StateNotifierProvider<IapNotifier, IapState>(
  (ref) => IapNotifier(ref),
);

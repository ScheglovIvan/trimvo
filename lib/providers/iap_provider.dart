import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:trimvo/models/gem_package_model.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:trimvo/providers/subscription_plans_provider.dart';
import 'package:trimvo/services/api_service.dart';

const Object _kUnset = Object();

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
  IapNotifier(this._ref) : super(const IapState()) {
    if (Platform.isIOS) {
      _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
        _onPurchasesUpdated,
        onError: (Object error) {
          debugPrint('[IAP] stream error: $error');
          if (mounted) state = state.copyWith(error: error.toString(), isLoading: false);
        },
      );
    }
  }

  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // apple_product_id -> backend gem-package ID
  final Map<String, String> _productToGemPackageId = {};
  // apple_product_id -> backend subscription-plan ID
  final Map<String, String> _productToSubPlanId = {};

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

  Future<void> purchaseGemPackage(GemPackageModel package) async {
    if (!Platform.isIOS) return;

    final productId = package.appleProductId;
    debugPrint('[IAP] purchaseGemPackage: id=${package.id} appleProductId=$productId');
    if (productId == null || productId.isEmpty) {
      if (mounted) state = state.copyWith(error: 'This package is not available', isLoading: false);
      return;
    }

    if (mounted) state = state.copyWith(isLoading: true, error: null, lastPurchaseType: null);

    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        if (mounted) state = state.copyWith(error: 'App Store is not available', isLoading: false);
        return;
      }
      debugPrint('[IAP] queryProductDetails: $productId');
      final response = await InAppPurchase.instance.queryProductDetails({productId});
      debugPrint('[IAP] found=${response.productDetails.length} notFound=${response.notFoundIDs}');
      if (response.productDetails.isEmpty) {
        if (mounted) state = state.copyWith(error: 'Product not found in App Store (id: $productId)', isLoading: false);
        return;
      }
      _productToGemPackageId[productId] = package.id;
      await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> purchaseSubscription(SubscriptionPlanModel plan) async {
    if (!Platform.isIOS) return;

    final productId = plan.appleProductId;
    debugPrint('[IAP] purchaseSubscription: id=${plan.id} appleProductId=$productId');
    if (productId == null || productId.isEmpty) {
      if (mounted) state = state.copyWith(error: 'This plan is not available', isLoading: false);
      return;
    }

    if (mounted) state = state.copyWith(isLoading: true, error: null, lastPurchaseType: null);

    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        if (mounted) state = state.copyWith(error: 'App Store is not available', isLoading: false);
        return;
      }
      debugPrint('[IAP] queryProductDetails: $productId');
      final response = await InAppPurchase.instance.queryProductDetails({productId});
      debugPrint('[IAP] found=${response.productDetails.length} notFound=${response.notFoundIDs}');
      if (response.productDetails.isEmpty) {
        if (mounted) state = state.copyWith(error: 'Product not found in App Store (id: $productId)', isLoading: false);
        return;
      }
      _productToSubPlanId[productId] = plan.id;
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> restorePurchases() async {
    if (!Platform.isIOS) return;

    if (mounted) state = state.copyWith(isLoading: true, error: null, lastPurchaseType: null);
    _isRestoring = true;
    _restoredJws.clear();

    // Timer fires when no new restored transactions arrive for 4 seconds.
    _scheduleRestoreFinalize();

    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _isRestoring = false;
      _restoreTimer?.cancel();
      if (mounted) state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void clearError() {
    if (mounted) state = state.copyWith(error: null);
  }

  void clearLastPurchase() {
    if (mounted) state = state.copyWith(lastPurchaseType: null);
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  void _scheduleRestoreFinalize() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 4), _finalizeRestore);
  }

  Future<void> _finalizeRestore() async {
    _isRestoring = false;

    if (_restoredJws.isEmpty) {
      if (mounted) state = state.copyWith(isLoading: false, lastPurchaseType: 'restore');
      return;
    }

    try {
      await ApiService.restoreApplePurchases(jwsRepresentations: _restoredJws);
    } catch (e) {
      debugPrint('[IAP] restore backend error: $e');
    }

    try {
      await _ref.read(authProvider.notifier).refreshBalance();
    } catch (_) {}

    if (mounted) state = state.copyWith(isLoading: false, lastPurchaseType: 'restore');
  }

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    debugPrint('[IAP] ${purchase.productID} status=${purchase.status}');

    if (purchase.status == PurchaseStatus.pending) return;

    if (purchase.status == PurchaseStatus.canceled) {
      await InAppPurchase.instance.completePurchase(purchase);
      if (mounted) state = state.copyWith(isLoading: false);
      return;
    }

    if (purchase.status == PurchaseStatus.error) {
      await InAppPurchase.instance.completePurchase(purchase);
      final code = purchase.error?.code ?? '';
      if (code != 'SKErrorPaymentCancelled' && code != 'user_cancelled') {
        final msg = purchase.error?.message ?? 'Purchase failed';
        if (mounted) state = state.copyWith(error: msg, isLoading: false);
      } else {
        if (mounted) state = state.copyWith(isLoading: false);
      }
      return;
    }

    if (purchase.status == PurchaseStatus.restored) {
      final jws = purchase.verificationData.serverVerificationData;
      if (jws.isNotEmpty) _restoredJws.add(jws);
      await InAppPurchase.instance.completePurchase(purchase);
      if (_isRestoring) _scheduleRestoreFinalize();
      return;
    }

    if (purchase.status == PurchaseStatus.purchased) {
      await _verifyPurchase(purchase);
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final jws = purchase.verificationData.serverVerificationData;

    final gemPackageId = _productToGemPackageId[productId];
    if (gemPackageId != null) {
      await _verifyGemPurchase(purchase, jws, gemPackageId);
      _productToGemPackageId.remove(productId);
      return;
    }

    final planId = _productToSubPlanId[productId];
    if (planId != null) {
      await _verifySubscriptionPurchase(purchase, jws, planId);
      _productToSubPlanId.remove(productId);
      return;
    }

    // Unknown product — complete to avoid re-delivery
    await InAppPurchase.instance.completePurchase(purchase);
    if (mounted) state = state.copyWith(isLoading: false);
  }

  Future<void> _verifyGemPurchase(
    PurchaseDetails purchase,
    String jws,
    String packageId,
  ) async {
    try {
      final result = await ApiService.verifyApplePurchase(
        jwsRepresentation: jws,
        packageId: packageId,
      );
      // Finish only after successful 2xx
      await InAppPurchase.instance.completePurchase(purchase);

      final newBalance = (result['new_balance'] as num?)?.toInt();
      if (newBalance != null) {
        _ref.read(authProvider.notifier).updateGems(newBalance);
      } else {
        await _ref.read(authProvider.notifier).refreshBalance();
      }

      if (mounted) state = state.copyWith(isLoading: false, lastPurchaseType: 'gems');
    } on ApiException catch (e) {
      // 400/404 = invalid or already consumed — finish to clean up
      if (e.statusCode == 400 || e.statusCode == 404) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
      if (mounted) state = state.copyWith(error: e.message, isLoading: false);
    } catch (e) {
      // Network error — don't finish so StoreKit retries on next launch
      if (mounted) state = state.copyWith(error: 'Purchase verification failed', isLoading: false);
    }
  }

  Future<void> _verifySubscriptionPurchase(
    PurchaseDetails purchase,
    String jws,
    String planId,
  ) async {
    try {
      await ApiService.verifyAppleSubscription(
        jwsRepresentation: jws,
        planId: planId,
      );
      await InAppPurchase.instance.completePurchase(purchase);
      await _ref.read(authProvider.notifier).refreshBalance();
      if (mounted) state = state.copyWith(isLoading: false, lastPurchaseType: 'subscription');
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 404) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
      if (mounted) state = state.copyWith(error: e.message, isLoading: false);
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Subscription verification failed', isLoading: false);
    }
  }
}

final iapProvider = StateNotifierProvider<IapNotifier, IapState>(
  (ref) => IapNotifier(ref),
);

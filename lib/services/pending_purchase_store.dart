import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A purchase that StoreKit has already finished, but which has not yet been
/// delivered to our backend (no token, backend down, 5xx, no network…).
///
/// Finishing the StoreKit transaction immediately is mandatory: an unfinished
/// transaction blocks every later purchase of the same product with
/// `storekit_duplicate_product_object`. Delivery is therefore retried from this
/// local queue instead of from the StoreKit queue.
@immutable
class PendingPurchase {
  const PendingPurchase({
    required this.key,
    required this.kind,
    required this.productId,
    required this.backendId,
    required this.jws,
    this.attempts = 0,
  });

  /// Stable de-duplication key (transaction id when available).
  final String key;

  /// 'gems' | 'subscription'
  final String kind;
  final String productId;

  /// Backend gem-package id or subscription-plan id. May be empty when the
  /// purchase was recovered after a cold start without a known mapping.
  final String backendId;
  final String jws;
  final int attempts;

  bool get isSubscription => kind == 'subscription';

  PendingPurchase withAttempt() => PendingPurchase(
        key: key,
        kind: kind,
        productId: productId,
        backendId: backendId,
        jws: jws,
        attempts: attempts + 1,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind,
        'product_id': productId,
        'backend_id': backendId,
        'jws': jws,
        'attempts': attempts,
      };

  static PendingPurchase? fromJson(Map<String, dynamic> j) {
    final key = j['key']?.toString() ?? '';
    final jws = j['jws']?.toString() ?? '';
    if (key.isEmpty || jws.isEmpty) return null;
    return PendingPurchase(
      key: key,
      kind: j['kind']?.toString() ?? 'gems',
      productId: j['product_id']?.toString() ?? '',
      backendId: j['backend_id']?.toString() ?? '',
      jws: jws,
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Persistent storage for [PendingPurchase] plus the product -> backend-id
/// mapping, so a purchase that lands after an app restart still knows which
/// gem package / subscription plan it belongs to.
class PendingPurchaseStore {
  PendingPurchaseStore._();

  static const _pendingKey = 'iap_pending_deliveries_v1';
  static const _productMapKey = 'iap_product_map_v1';

  /// Give up on a delivery after this many failed attempts so the queue can
  /// never grow without bound. Restore still recovers such a purchase.
  static const maxAttempts = 12;

  // ── Pending deliveries ──────────────────────────────────────────────────────

  static Future<List<PendingPurchase>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(PendingPurchase.fromJson)
          .whereType<PendingPurchase>()
          .toList();
    } catch (e) {
      debugPrint('[IAP] pending load failed: $e');
      return [];
    }
  }

  static Future<void> _save(List<PendingPurchase> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[IAP] pending save failed: $e');
    }
  }

  static Future<void> add(PendingPurchase purchase) async {
    final items = await load();
    items.removeWhere((e) => e.key == purchase.key);
    items.add(purchase);
    await _save(items);
  }

  static Future<void> remove(String key) async {
    final items = await load();
    final before = items.length;
    items.removeWhere((e) => e.key == key);
    if (items.length != before) await _save(items);
  }

  static Future<void> replace(PendingPurchase purchase) async {
    final items = await load();
    final index = items.indexWhere((e) => e.key == purchase.key);
    if (index == -1) return;
    items[index] = purchase;
    await _save(items);
  }

  // ── Product -> backend id mapping ───────────────────────────────────────────

  static Future<void> rememberProduct(
    String productId, {
    required String kind,
    required String backendId,
  }) async {
    if (productId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = await _loadProductMap(prefs);
      map[productId] = {'kind': kind, 'id': backendId};
      await prefs.setString(_productMapKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[IAP] product map save failed: $e');
    }
  }

  /// Returns `(kind, backendId)` for a product id, or null when unknown.
  static Future<({String kind, String backendId})?> lookupProduct(
    String productId,
  ) async {
    if (productId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = await _loadProductMap(prefs);
      final entry = map[productId];
      if (entry is! Map) return null;
      final kind = entry['kind']?.toString();
      final id = entry['id']?.toString();
      if (kind == null || id == null || id.isEmpty) return null;
      return (kind: kind, backendId: id);
    } catch (e) {
      debugPrint('[IAP] product map read failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _loadProductMap(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_productMapKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {};
  }
}

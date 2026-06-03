import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/models/gem_package_model.dart';
import 'package:trimvo/services/api_service.dart';

const _fallbackPackages = [
  GemPackageModel(
    id: '1', gemsAmount: 800, bonusGems: 0, price: 679.99,
    currency: 'UAH', label: 'Starter', isPopular: false, order: 0,
  ),
  GemPackageModel(
    id: '2', gemsAmount: 2300, bonusGems: 300, price: 1599.99,
    currency: 'UAH', label: null, isPopular: false, order: 1,
  ),
  GemPackageModel(
    id: '3', gemsAmount: 3300, bonusGems: 500, price: 2099.99,
    currency: 'UAH', label: null, isPopular: false, order: 2,
  ),
  GemPackageModel(
    id: '4', gemsAmount: 6000, bonusGems: 1000, price: 3699.99,
    currency: 'UAH', label: null, isPopular: false, order: 3,
  ),
  GemPackageModel(
    id: '5', gemsAmount: 10000, bonusGems: 2000, price: 5249.99,
    currency: 'UAH', label: null, isPopular: true, order: 4,
  ),
];

final gemPackagesProvider = FutureProvider<List<GemPackageModel>>((ref) async {
  try {
    final packages = await ApiService.getGemPackages();
    if (packages.isEmpty) return _fallbackPackages;
    return packages;
  } catch (e) {
    debugPrint('GemPackages error: $e');
    return _fallbackPackages;
  }
});

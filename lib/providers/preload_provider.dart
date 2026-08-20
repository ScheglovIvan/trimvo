import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/models/category_model.dart';
import 'package:trimvo/models/template_model.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:trimvo/providers/categories_provider.dart';
import 'package:trimvo/providers/iap_provider.dart';
import 'package:trimvo/providers/pricing_provider.dart';
import 'package:trimvo/providers/templates_provider.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';

class PreloadState {
  const PreloadState({this.total = 0, this.done = 0, this.complete = false});

  final int total;
  final int done;
  final bool complete;

  double get progress => total > 0 ? done / total : 0.0;

  PreloadState copyWith({int? total, int? done, bool? complete}) => PreloadState(
        total: total ?? this.total,
        done: done ?? this.done,
        complete: complete ?? this.complete,
      );
}

class PreloadNotifier extends StateNotifier<PreloadState> {
  PreloadNotifier(this._ref) : super(const PreloadState());

  final Ref _ref;
  bool _started = false;

  /// Starts pre-caching. Idempotent — safe to call multiple times.
  /// Returns only after all resources are cached (or failed).
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Auth
    try { await _ref.read(authProvider.notifier).loadFromStorage(); } catch (_) {}

    // StoreKit: attach the purchase listener and clear any transaction left
    // unfinished by a previous session. Must happen before the paywall can be
    // opened, otherwise a stale transaction blocks the next purchase.
    // Runs detached so a slow App Store call never delays the splash.
    unawaited(_ref.read(iapProvider.notifier).init());

    // Pricing + categories
    List<CategoryModel> cats = [];
    await Future.wait([
      Future<void>(() async {
        try { await _ref.read(pricingProvider.future); } catch (_) {}
      }),
      Future<void>(() async {
        try { cats = await _ref.read(categoriesProvider.future); } catch (_) {}
      }),
    ]);

    // All template lists: trending + every category
    Future<List<TemplateModel>> fetch(TemplatesParams p) async {
      try { return await _ref.read(templatesProvider(p).future); } catch (_) { return []; }
    }

    final templateFutures = <Future<List<TemplateModel>>>[
      fetch(const TemplatesParams(trending: true, perPage: 20)),
    ];
    for (final cat in cats) {
      templateFutures.add(fetch(TemplatesParams(categoryId: cat.id, perPage: 8)));
    }
    final allLists = await Future.wait(templateFutures);

    // Collect unique compressed preview URLs
    final urls = <String>{};
    for (final list in allLists) {
      for (final t in list) {
        final url = t.previewCompressedUrl ?? t.previewUrl;
        if (url != null && url.isNotEmpty) urls.add(url);
      }
    }
    if (mounted) state = state.copyWith(total: urls.length);

    // Download to file cache — 3 concurrent
    final urlList = urls.toList();
    for (var i = 0; i < urlList.length; i += 3) {
      await Future.wait(
        urlList.skip(i).take(3).map((url) async {
          try { await VideoCacheManager().getSingleFile(url); } catch (_) {}
          if (mounted) state = state.copyWith(done: state.done + 1);
        }),
      );
    }

    if (mounted) state = state.copyWith(complete: true);
  }
}

final preloadProvider =
    StateNotifierProvider<PreloadNotifier, PreloadState>((ref) {
  return PreloadNotifier(ref);
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/models/template_model.dart';
import 'package:trimvo/services/api_service.dart';

// Module-level cache — lives for the app's lifetime, survives navigation.
final Map<TemplatesParams, (List<TemplateModel>, DateTime)> _templateCache = {};
const _cacheTtl = Duration(minutes: 5);

void clearTemplatesCache() => _templateCache.clear();

final templatesProvider = FutureProvider.family<List<TemplateModel>, TemplatesParams>(
  (ref, params) async {
    if (_templateCache.containsKey(params)) {
      final (cached, time) = _templateCache[params]!;
      if (DateTime.now().difference(time) < _cacheTtl) {
        return cached;
      }
      _templateCache.remove(params);
    }
    final data = await ApiService.getTemplates(
      categoryId: params.categoryId,
      trending: params.trending,
      page: params.page,
      perPage: params.perPage,
    );
    debugPrint('Templates API response: ${data['total']} items, trending=${params.trending}, category=${params.categoryId}');
    final items = data['items'] as List<dynamic>? ?? [];
    debugPrint('First item: ${items.isNotEmpty ? items.first : 'EMPTY'}');
    final result = items
        .map((e) => TemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _templateCache[params] = (result, DateTime.now());
    return result;
  },
);

final templateDetailProvider = FutureProvider.family<TemplateModel, String>(
  (ref, id) async {
    final data = await ApiService.getTemplate(id);
    return TemplateModel.fromJson(data);
  },
);

class TemplatesParams {
  const TemplatesParams({
    this.categoryId,
    this.trending,
    this.page = 1,
    this.perPage = 20,
  });

  final String? categoryId;
  final bool? trending;
  final int page;
  final int perPage;

  @override
  bool operator ==(Object other) =>
      other is TemplatesParams &&
      other.categoryId == categoryId &&
      other.trending == trending &&
      other.page == page &&
      other.perPage == perPage;

  @override
  int get hashCode => Object.hash(categoryId, trending, page, perPage);
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/models/category_model.dart';
import 'package:trimvo/services/api_service.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final rawList = await ApiService.getCategories();
  debugPrint('Categories API: ${rawList.length} items');
  if (rawList.isNotEmpty) debugPrint('First category: ${rawList.first}');
  return rawList.map(CategoryModel.fromJson).toList();
});

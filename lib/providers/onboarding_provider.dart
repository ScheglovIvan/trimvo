import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/services/api_service.dart';

final onboardingVideosProvider = FutureProvider<List<String>>((ref) async {
  return ApiService.getOnboardingVideos();
});

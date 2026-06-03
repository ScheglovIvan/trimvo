import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/providers/onboarding_provider.dart';
import 'package:trimvo/shared/widgets/dynamic_video_grid.dart';
import 'package:trimvo/shared/widgets/scrolling_gif_grid.dart';

class SmartVideoGrid extends ConsumerWidget {
  const SmartVideoGrid({
    super.key,
    required this.controller,
    this.speeds = const [0.3, 0.3, 0.3],
    this.offsets = const [0.0, -0.5, 0.0],
  });

  final AnimationController controller;
  final List<double> speeds;
  final List<double> offsets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(onboardingVideosProvider);

    return async.when(
      loading: () => ScrollingGifGrid(
        controller: controller,
        speeds: speeds,
        offsets: offsets,
      ),
      error: (_, __) => ScrollingGifGrid(
        controller: controller,
        speeds: speeds,
        offsets: offsets,
      ),
      data: (urls) => urls.isEmpty
          ? ScrollingGifGrid(
              controller: controller,
              speeds: speeds,
              offsets: offsets,
            )
          : DynamicVideoGrid(
              controller: controller,
              videoUrls: urls,
              speeds: speeds,
              offsets: offsets,
            ),
    );
  }
}

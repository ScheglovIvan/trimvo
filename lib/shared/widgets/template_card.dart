import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/theme/app_gradients.dart';
import 'package:trimvo/core/theme/app_text_styles.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:trimvo/shared/widgets/plays_counter.dart';

class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppColors.backgroundCard)
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white10);
  }
}

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.title,
    required this.thumbnailUrl,
    this.playsCount,
    this.onTap,
    this.isSelected = false,
  });

  final String title;
  final String thumbnailUrl;
  final String? playsCount;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: AppColors.backgroundCard,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.accentPurple.withOpacity(0.2),
            highlightColor: AppColors.accentPurple.withOpacity(0.1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnailUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    cacheManager: AppCacheManager(),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => const ShimmerPlaceholder(),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: AppColors.backgroundCard,
                    ),
                  ),
                // Selection border
                if (isSelected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentPurpleLight,
                        width: 2,
                      ),
                    ),
                  ),
                // Bottom gradient overlay
                const Positioned(
                  bottom: -2,
                  left: -1,
                  right: -1,
                  height: 84,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppGradients.cardOverlay,
                    ),
                  ),
                ),
                // Title + plays row
                Positioned(
                  bottom: 0,
                  left: 12,
                  right: 12,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (playsCount != null) ...[
                          const SizedBox(height: 4),
                          PlaysCounter(count: playsCount!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

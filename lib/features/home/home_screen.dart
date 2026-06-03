import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/widgets/app_background.dart';
import 'package:trimvo/features/profile/profile_bottom_sheet.dart';
import 'package:trimvo/models/category_model.dart';
import 'package:trimvo/models/template_model.dart';
import 'package:trimvo/providers/active_video_provider.dart';
import 'package:trimvo/providers/categories_provider.dart';
import 'package:trimvo/providers/templates_provider.dart';
import 'package:trimvo/shared/utils/video_utils.dart';
import 'package:trimvo/shared/widgets/app_bottom_nav.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:trimvo/shared/widgets/svip_badge.dart';
import 'package:trimvo/shared/widgets/template_card.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;


  Future<void> _onRefresh() async {
    clearTemplatesCache();
    ref.invalidate(templatesProvider);
    ref.invalidate(categoriesProvider);
  }

  void _precacheTemplates(List<TemplateModel> templates) {
    for (final t in templates) {
      if (t.thumbUrl != null && t.thumbUrl!.isNotEmpty) {
        CachedNetworkImageProvider(
          t.thumbUrl!,
          cacheManager: AppCacheManager(),
        ).resolve(ImageConfiguration.empty);
      }
    }
  }

  Widget _buildFeaturedCarousel(
      BuildContext context, List<TemplateModel> templates) {
    if (templates.isEmpty) return const _ShimmerFeatured();
    return _FeaturedCarousel(
      templates: templates,
      onCardTap: (i) =>
          context.push('/template-swipe?trending=true&index=$i'),
    );
  }

  List<Widget> _buildCategorySlivers(
      AsyncValue<List<CategoryModel>> categoriesAsync) {
    return categoriesAsync.when(
      loading: () => [
        for (int i = 0; i < 3; i++) ...[
          const SliverToBoxAdapter(
            child: _SectionHeader(
              emoji: '',
              title: '',
              isPlaceholder: true,
            ),
          ),
          const SliverToBoxAdapter(child: _ShimmerRow()),
        ],
      ],
      error: (_, __) => [],
      data: (apiCategories) {
        final sorted = [...apiCategories]
          ..sort((a, b) => a.order.compareTo(b.order));

        return [
          for (final cat in sorted) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                emoji: _emojiForCategory(cat.name),
                title: cat.name,
                onSeeAll: () => context.push(
                  '/category/${Uri.encodeComponent(cat.name)}?id=${cat.id}',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoryRowFromApi(
                categoryId: cat.id,
                categoryName: cat.name,
              ),
            ),
          ],
        ];
      },
    );
  }

  String _emojiForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('couple')) return '💑';
    if (lower.contains('dance')) return '🕺';
    if (lower.contains('goddess') || lower.contains('aura')) return '✨';
    if (lower.contains('home') || lower.contains('cozy')) return '🏠';
    return '🎬';
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(
      templatesProvider(const TemplatesParams(trending: true)),
    );
    final categoriesAsync = ref.watch(categoriesProvider);

    ref.listen<AsyncValue<List<TemplateModel>>>(
      templatesProvider(const TemplatesParams(trending: true)),
      (_, next) => next.whenData(_precacheTemplates),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            title: const Text(
              'Exit app?',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Exit',
                  style: TextStyle(color: AppColors.accentPurple),
                ),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          bottomNavigationBar: AppBottomNav(
            currentIndex: _navIndex,
            onTap: (i) {
              setState(() => _navIndex = i);
              if (i == 1) context.go('/history');
            },
          ),
          body: SafeArea(
            child: Column(
              children: [
                // ── Закреплённый топ-бар ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/paywall?svip=true'),
                        child: const SvipBadge(),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A28),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => showProfileBottomSheet(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2A1A3E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Скроллируемый контент ─────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppColors.accentPurple,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── Featured ────────────────────────────────────────
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            emoji: '🔥',
                            title: 'Featured',
                            onSeeAll: () =>
                                context.push('/category/Featured?trending=true'),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: trendingAsync.when(
                            loading: () => const _ShimmerFeatured(),
                            error: (_, __) => const _ShimmerFeatured(),
                            data: (trending) =>
                                _buildFeaturedCarousel(context, trending),
                          ),
                        ),

                        // ── Action buttons ───────────────────────────────────
                        const SliverToBoxAdapter(child: _ActionButtons()),

                        // ── Categories (API + fallback) ──────────────────────
                        ..._buildCategorySlivers(categoriesAsync),

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.emoji,
    required this.title,
    this.onSeeAll,
    this.isPlaceholder = false,
  });

  final String emoji;
  final String title;
  final VoidCallback? onSeeAll;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (isPlaceholder) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const SizedBox(
            height: 18,
            width: 140,
            child: ShimmerPlaceholder(),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Text(
            '$emoji $title',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A28),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right,
                      color: AppColors.textPrimary, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHIMMER PLACEHOLDERS
// ═══════════════════════════════════════════════════════════════════════════════

class _ShimmerFeatured extends StatelessWidget {
  const _ShimmerFeatured();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: 4,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: const ShimmerPlaceholder(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: const ShimmerPlaceholder(),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURED CAROUSEL
// ═══════════════════════════════════════════════════════════════════════════════

class _FeaturedCarousel extends ConsumerStatefulWidget {
  const _FeaturedCarousel({
    this.templates,
    this.onCardTap,
  });

  final List<TemplateModel>? templates;
  final void Function(int index)? onCardTap;

  @override
  ConsumerState<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<_FeaturedCarousel> {
  late final PageController _ctrl;
  double _page = 0.0;

  int get _count => widget.templates?.length ?? 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(
      viewportFraction: 0.48,
      initialPage: _count * 500,
    );
    _page = _ctrl.initialPage.toDouble();
    _ctrl.addListener(() {
      if (mounted) setState(() => _page = _ctrl.page ?? _page);
      ref.read(activeVideoProvider.notifier).state = 'featured';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatPlays(int plays) {
    if (plays >= 1000) return '${(plays / 1000).floor()}k';
    return '$plays';
  }

  @override
  Widget build(BuildContext context) {
    final activeKey = ref.watch(activeVideoProvider);

    if (_count == 0) return const SizedBox(height: 252);
    return SizedBox(
      height: 252,
      child: PageView.builder(
        controller: _ctrl,
        itemCount: _count * 1000,
        itemBuilder: (context, i) {
          final realIndex = i % _count;
          final template = widget.templates![realIndex];
          final title = template.title;
          final thumbUrl = template.thumbUrl;
          final gifUrl = template.gifUrl;

          final diff = i - _page;
          final isCenter = diff.abs() < 0.5;

          final card = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 1: thumb (always shown)
                    if (thumbUrl != null)
                      CachedNetworkImage(
                        imageUrl: thumbUrl,
                        cacheManager: AppCacheManager(),
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => const ShimmerPlaceholder(),
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: AppColors.backgroundCard),
                      )
                    else
                      const ColoredBox(color: AppColors.backgroundCard),

                    // Layer 2: gif over thumb (center card only, when featured is active)
                    if (isCenter && gifUrl != null && activeKey == 'featured')
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 400),
                        child: CachedNetworkImage(
                          imageUrl: gifUrl,
                          cacheManager: AppCacheManager(),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 10,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    AppColors.playsRose,
                                    AppColors.playsLemon,
                                  ],
                                  stops: [0.25, 0.75],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_arrow,
                                        color: Colors.white, size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_formatPlays(template.plays)} plays',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          final scale = (1.0 - diff.abs() * 0.15).clamp(0.85, 1.0);
          final rotation = diff.clamp(-1.0, 1.0) * 0.15;
          return GestureDetector(
            onTap: () => widget.onCardTap?.call(realIndex),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..rotateZ(rotation)
                ..scale(scale),
              child: RepaintBoundary(child: card),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION BUTTONS
// ═══════════════════════════════════════════════════════════════════════════════

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.play_circle_outline_rounded,
              label: 'Create Video',
              onPressed: () => context.push('/create'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: Icons.add_photo_alternate_outlined,
              label: 'Create Image',
              onPressed: () => context.push('/home/create-image'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A3E), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 26),
                const Positioned(
                  top: -4,
                  right: -6,
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.accentPurple,
                    size: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY ROW WITH API FALLBACK
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryRowFromApi extends ConsumerWidget {
  const _CategoryRowFromApi({
    required this.categoryId,
    required this.categoryName,
  });

  final String categoryId;
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categoryId.isEmpty) return const _ShimmerRow();

    final async = ref.watch(
      templatesProvider(TemplatesParams(categoryId: categoryId, perPage: 8)),
    );
    return async.when(
      loading: () => const _ShimmerRow(),
      error: (_, __) => const _ShimmerRow(),
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();
        return _CategoryRowApi(
          categoryName: categoryName,
          templates: templates,
          onCardTap: (i) => context.push(
            '/template-swipe'
            '?categoryId=$categoryId'
            '&trending=false'
            '&index=$i',
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY ROW API (with scroll-based preview)
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryRowApi extends ConsumerStatefulWidget {
  const _CategoryRowApi({
    required this.categoryName,
    required this.templates,
    required this.onCardTap,
  });

  final String categoryName;
  final List<TemplateModel> templates;
  final void Function(int) onCardTap;

  @override
  ConsumerState<_CategoryRowApi> createState() => _CategoryRowApiState();
}

class _CategoryRowApiState extends ConsumerState<_CategoryRowApi>
    with WidgetsBindingObserver {
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, VideoPlayerController> _videoControllers = {};
  int _firstVisibleIndex = 0;

  // item width = 200 * (9/16) = 112.5; spacing = 10
  static const double _itemExtent = 200.0 * 9 / 16 + 10.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.templates.isNotEmpty) {
        final t = widget.templates[0];
        final url = t.previewCompressedUrl ?? t.previewUrl;
        if (url != null) _initAndPlayController(0, url);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    for (final ctrl in _videoControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      for (final ctrl in _videoControllers.values) {
        ctrl.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      _videoControllers[_firstVisibleIndex]?.play();
    }
  }

  Future<void> _initAndPlayController(int index, String url) async {
    if (_videoControllers.containsKey(index)) return;
    final ctrl = await initCachedVideoController(url);
    if (ctrl == null) return;
    if (mounted) {
      setState(() => _videoControllers[index] = ctrl);
    } else {
      ctrl.dispose();
    }
  }

  void _onScroll() {
    if (!mounted) return;
    ref.read(activeVideoProvider.notifier).state =
        'category_${widget.categoryName}';
    final newIndex = (_scrollCtrl.offset / _itemExtent)
        .floor()
        .clamp(0, widget.templates.length - 1);
    if (newIndex != _firstVisibleIndex) {
      _videoControllers[_firstVisibleIndex]?.pause();
      _videoControllers[_firstVisibleIndex]?.dispose();
      _videoControllers.remove(_firstVisibleIndex);
      setState(() => _firstVisibleIndex = newIndex);

      final t = widget.templates[newIndex];
      final url = t.previewCompressedUrl ?? t.previewUrl;
      if (url != null) _initAndPlayController(newIndex, url);

      // Lookahead: предзагрузить следующий
      final nextIndex = newIndex + 1;
      if (nextIndex < widget.templates.length) {
        final next = widget.templates[nextIndex];
        final nextUrl = next.previewCompressedUrl ?? next.previewUrl;
        if (nextUrl != null) _initAndPlayController(nextIndex, nextUrl);
      }
    }
  }

  String _formatCategoryPlays(int plays) {
    if (plays >= 1000) return '${(plays / 1000).floor()}k';
    return '$plays';
  }

  @override
  Widget build(BuildContext context) {
    final activeKey = ref.watch(activeVideoProvider);

    return SizedBox(
      height: 200,
      child: ListView.builder(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.templates.length,
        itemBuilder: (context, i) {
          final t = widget.templates[i];
          final isFirst = i == _firstVisibleIndex;
          final ctrl = _videoControllers[i];
          final videoReady = ctrl != null && ctrl.value.isInitialized;
          final showGif = isFirst &&
              !videoReady &&
              t.gifUrl != null &&
              activeKey == 'category_${widget.categoryName}';

          return GestureDetector(
            onTap: () => widget.onCardTap(i),
            child: Padding(
              padding: EdgeInsets.only(
                  right: i < widget.templates.length - 1 ? 10 : 0),
              child: RepaintBoundary(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layer 1: thumb (always shown)
                        if (t.thumbUrl != null)
                          CachedNetworkImage(
                            imageUrl: t.thumbUrl!,
                            cacheManager: AppCacheManager(),
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            fadeInDuration:
                                const Duration(milliseconds: 200),
                            placeholder: (_, __) =>
                                const ShimmerPlaceholder(),
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(
                                    color: AppColors.backgroundCard),
                          )
                        else
                          const ColoredBox(color: AppColors.backgroundCard),

                        // Layer 2: gif over thumb
                        if (t.gifUrl != null)
                          AnimatedOpacity(
                            opacity: showGif ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: RepaintBoundary(
                              child: CachedNetworkImage(
                                imageUrl: t.gifUrl!,
                                cacheManager: AppCacheManager(),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),

                        // Layer 3: compressed video (when ready)
                        if (videoReady)
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: ctrl.value.size.width,
                                height: ctrl.value.size.height,
                                child: VideoPlayer(ctrl),
                              ),
                            ),
                          ),

                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.80),
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(14),
                              ),
                            ),
                            padding:
                                const EdgeInsets.fromLTRB(8, 20, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        AppColors.playsRose,
                                        AppColors.playsLemon,
                                      ],
                                      stops: [0.25, 0.75],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.play_arrow,
                                            color: Colors.white, size: 11),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${_formatCategoryPlays(t.plays)} plays',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


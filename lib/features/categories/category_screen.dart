import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/widgets/app_background.dart';
import 'package:trimvo/models/template_model.dart';
import 'package:trimvo/providers/templates_provider.dart';
import 'package:trimvo/shared/utils/video_utils.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:trimvo/shared/widgets/template_card.dart';
import 'package:video_player/video_player.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({
    super.key,
    required this.name,
    this.categoryId,
    this.trending = false,
  });

  final String name;
  final String? categoryId;
  final bool trending;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen>
    with WidgetsBindingObserver {
  final ScrollController _gridScrollCtrl = ScrollController();
  final Map<int, VideoPlayerController> _videoControllers = {};
  Set<int> _activeIndices = {0, 1};

  TemplatesParams get _params {
    if (widget.trending) return const TemplatesParams(trending: true);
    if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      return TemplatesParams(categoryId: widget.categoryId);
    }
    return const TemplatesParams(trending: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gridScrollCtrl.addListener(_onGridScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gridScrollCtrl.removeListener(_onGridScroll);
    _gridScrollCtrl.dispose();
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
      for (final i in _activeIndices) {
        _videoControllers[i]?.play();
      }
    }
  }

  void _onGridScroll() {
    if (!mounted || !_gridScrollCtrl.hasClients) return;
    final offset = _gridScrollCtrl.offset;

    Set<int> newActive;
    if (offset < 30) {
      newActive = {0, 1};
    } else {
      final size = MediaQuery.of(context).size;
      final cardW = (size.width - 44) / 2;
      final cardH = cardW * (5 / 3) + 12;
      final centerOffset = offset + size.height / 2;
      final centerRow = ((centerOffset - 16) / cardH).round().clamp(0, 999);
      newActive = {centerRow * 2, centerRow * 2 + 1};
    }

    if (newActive == _activeIndices) return;

    for (final i in _activeIndices) {
      if (!newActive.contains(i)) {
        _videoControllers[i]?.pause();
        _videoControllers[i]?.dispose();
        _videoControllers.remove(i);
      }
    }

    setState(() => _activeIndices = newActive);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(templatesProvider(_params));

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: async.when(
                  loading: () => _buildEmptyGrid(),
                  error: (_, __) => _buildEmptyGrid(),
                  data: (templates) => templates.isEmpty
                      ? _buildEmptyGrid()
                      : _buildApiGrid(context, templates),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.backgroundCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              widget.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3 / 5,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: const ShimmerPlaceholder(),
      ),
    );
  }

  Widget _buildApiGrid(BuildContext context, List<TemplateModel> templates) {
    return GridView.builder(
      controller: _gridScrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3 / 5,
      ),
      itemCount: templates.length,
      itemBuilder: (context, i) {
        final t = templates[i];
        return RepaintBoundary(
          child: _VideoGridCard(
            template: t,
            controller: _videoControllers[i],
            isActive: _activeIndices.contains(i),
            onActivate: () {
              final videoUrl = t.previewCompressedUrl ?? t.previewUrl;
              if (videoUrl != null) {
                _initAndPlayController(i, videoUrl);
              }
            },
            onTap: () => context.push(
              '/template-swipe'
              '?categoryId=${widget.categoryId ?? ""}'
              '&trending=${widget.trending}'
              '&index=$i',
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VIDEO GRID CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _VideoGridCard extends StatefulWidget {
  const _VideoGridCard({
    required this.template,
    required this.controller,
    required this.isActive,
    required this.onActivate,
    required this.onTap,
  });

  final TemplateModel template;
  final VideoPlayerController? controller;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onTap;

  @override
  State<_VideoGridCard> createState() => _VideoGridCardState();
}

class _VideoGridCardState extends State<_VideoGridCard> {
  String _formatPlays(int plays) {
    if (plays >= 1000) return '${(plays / 1000).floor()}k';
    return '$plays';
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) widget.onActivate();
  }

  @override
  void didUpdateWidget(_VideoGridCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) widget.onActivate();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final videoReady = ctrl != null && ctrl.value.isInitialized;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: thumb (always)
            if (widget.template.thumbUrl != null)
              CachedNetworkImage(
                imageUrl: widget.template.thumbUrl!,
                cacheManager: AppCacheManager(),
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const ColoredBox(color: AppColors.backgroundCard),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: AppColors.backgroundCard),
              )
            else
              const ColoredBox(color: AppColors.backgroundCard),

            // Layer 2: GIF overlay (visible when active but video not yet ready)
            if (widget.template.gifUrl != null)
              AnimatedOpacity(
                opacity: widget.isActive && !videoReady ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: RepaintBoundary(
                  child: CachedNetworkImage(
                    imageUrl: widget.template.gifUrl!,
                    cacheManager: AppCacheManager(),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Layer 3: video overlay (when ready)
            if (videoReady)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: ctrl.value.size.width,
                    height: ctrl.value.size.height,
                    child: VideoPlayer(ctrl),
                  ),
                ),
              ),

            // Title + plays
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: _CardLabel(
                title: widget.template.title,
                playsText: '${_formatPlays(widget.template.plays)} plays',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED LABEL WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.title, required this.playsText});

  final String title;
  final String playsText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.playsRose, AppColors.playsLemon],
              stops: [0.25, 0.75],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                const SizedBox(width: 3),
                Text(
                  playsText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

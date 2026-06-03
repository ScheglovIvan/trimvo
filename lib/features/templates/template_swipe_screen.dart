import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/features/templates/report_bottom_sheet.dart';
import 'package:trimvo/models/template_model.dart';
import 'package:trimvo/providers/likes_provider.dart';
import 'package:trimvo/providers/templates_provider.dart';
import 'package:trimvo/shared/utils/video_utils.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:video_player/video_player.dart';

class TemplateSwipeScreen extends ConsumerStatefulWidget {
  const TemplateSwipeScreen({
    super.key,
    this.categoryId,
    this.trending = false,
    this.initialIndex = 0,
  });

  final String? categoryId;
  final bool trending;
  final int initialIndex;

  @override
  ConsumerState<TemplateSwipeScreen> createState() =>
      _TemplateSwipeScreenState();
}

class _TemplateSwipeScreenState extends ConsumerState<TemplateSwipeScreen> {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _videoControllers = {};
  int _currentIndex = 0;

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
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initVideo(int index, String url) async {
    if (_videoControllers.containsKey(index)) return;
    final ctrl = await initCachedVideoController(url);
    if (ctrl == null) return;
    if (mounted) {
      setState(() => _videoControllers[index] = ctrl);
    } else {
      ctrl.dispose();
    }
  }

  void _onPageChanged(int index, List<TemplateModel> templates) {
    _videoControllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);

    final t = templates[index];
    final url = t.previewUrl;
    if (url != null) _initVideo(index, url);

    if (index + 1 < templates.length) {
      final next = templates[index + 1];
      if (next.previewUrl != null) _initVideo(index + 1, next.previewUrl!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(templatesProvider(_params));

    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentPurple),
        ),
        error: (_, __) => const Center(
          child: Text('Error',
              style: TextStyle(color: AppColors.textPrimary)),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
              child: Text('No templates',
                  style: TextStyle(color: AppColors.textPrimary)),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final t = templates[_currentIndex];
            if (t.previewUrl != null) _initVideo(_currentIndex, t.previewUrl!);
          });

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: templates.length,
            onPageChanged: (i) => _onPageChanged(i, templates),
            itemBuilder: (context, index) {
              final t = templates[index];
              final ctrl = _videoControllers[index];
              final videoReady = ctrl != null && ctrl.value.isInitialized;

              return _SwipePage(
                template: t,
                controller: ctrl,
                videoReady: videoReady,
                onUseTemplate: () => context.push(
                  '/upload?templateId=${Uri.encodeComponent(t.id)}',
                ),
                onBack: () => context.pop(),
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ОДНА СТРАНИЦА СВАЙПА
// ═══════════════════════════════════════════════════════════════════════════════

class _SwipePage extends ConsumerStatefulWidget {
  const _SwipePage({
    required this.template,
    required this.controller,
    required this.videoReady,
    required this.onUseTemplate,
    required this.onBack,
  });

  final TemplateModel template;
  final VideoPlayerController? controller;
  final bool videoReady;
  final VoidCallback onUseTemplate;
  final VoidCallback onBack;

  @override
  ConsumerState<_SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends ConsumerState<_SwipePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimCtrl;
  late Animation<double> _likeScaleAnim;

  @override
  void initState() {
    super.initState();
    _likeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_likeAnimCtrl);
  }

  @override
  void dispose() {
    _likeAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;
    final likedIds = ref.watch(likesProvider);
    final isLiked = likedIds.contains(widget.template.id);
    final displayLikes = widget.template.likes + (isLiked ? 1 : 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Фон: thumb → video
        if (widget.videoReady && widget.controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: widget.controller!.value.size.width,
              height: widget.controller!.value.size.height,
              child: VideoPlayer(widget.controller!),
            ),
          )
        else if (widget.template.thumbUrl != null)
          CachedNetworkImage(
            imageUrl: widget.template.thumbUrl!,
            cacheManager: AppCacheManager(),
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
            errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),

        // Градиент снизу
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black],
              ),
            ),
          ),
        ),

        // Кнопка назад — левый верхний угол
        Positioned(
          top: topPad + 12,
          left: 16,
          child: GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            ),
          ),
        ),

        // Кнопка жалобы — правый верхний угол
        Positioned(
          top: topPad + 12,
          right: 16,
          child: GestureDetector(
            onTap: () =>
                showReportBottomSheet(context, widget.template.id),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),

        // Лайк — справа над кнопкой Use Template
        Positioned(
          right: 16,
          bottom: bottomPad + 110,
          child: GestureDetector(
            onTap: () {
              _likeAnimCtrl.forward(from: 0);
              ref
                  .read(likesProvider.notifier)
                  .toggleLike(widget.template.id);
            },
            child: ScaleTransition(
              scale: _likeScaleAnim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.redAccent : Colors.white,
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatLikes(displayLikes),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Название — слева над кнопкой
        Positioned(
          left: 16,
          right: 72,
          bottom: bottomPad + 110,
          child: Text(
            widget.template.title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Кнопка Use Template — без цены, с градиентом
        Positioned(
          left: 16,
          right: 16,
          bottom: bottomPad + 24,
          child: GestureDetector(
            onTap: widget.onUseTemplate,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B2FD9), Color(0xFF9B59F5)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentPurple.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '✦ ',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  Text(
                    'Use Template',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatLikes(int likes) {
    if (likes >= 1000) return '${(likes / 1000).toStringAsFixed(0)}k';
    return '$likes';
  }
}

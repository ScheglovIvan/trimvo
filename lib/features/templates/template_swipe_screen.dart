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
import 'dart:io';
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

class _TemplateSwipeScreenState extends ConsumerState<TemplateSwipeScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Set<int> _initializingIndices = {};
  // Indices whose URL failed (SSL cert expired, network error, etc.) — never retry.
  final Set<int> _failedIndices = {};
  // Queue: sequential init to avoid exhausting the hardware H.264 decoder pool.
  final List<(int, String, String?)> _initQueue = [];
  bool _queueRunning = false;
  int _currentIndex = 0;
  bool _didInitFirst = false;

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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initQueue.clear();
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c.pause();
      c.dispose();
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
      _videoControllers[_currentIndex]?.play();
    }
  }

  @override
  void deactivate() {
    for (final ctrl in _videoControllers.values) {
      ctrl.pause();
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _videoControllers[_currentIndex]?.play();
  }

  // Primary = previewUrl (higher quality). Fallback = previewCompressedUrl (different CDN,
  // valid SSL). Both returned so _initVideo can try one then the other.
  (String primary, String? fallback) _videoUrls(TemplateModel t) => (
        t.previewUrl ?? t.previewCompressedUrl ?? '',
        t.previewUrl != null ? t.previewCompressedUrl : null,
      );

  // Enqueue an init request. priority=true inserts at front (current page).
  void _enqueueInit(int index, String primary, String? fallback,
      {bool priority = false}) {
    if (primary.isEmpty) return;
    if (_videoControllers.containsKey(index)) return;
    if (_initializingIndices.contains(index)) return;
    if (_failedIndices.contains(index)) return;
    _initQueue.removeWhere((e) => e.$1 == index);
    final entry = (index, primary, fallback);
    if (priority) {
      _initQueue.insert(0, entry);
    } else {
      _initQueue.add(entry);
    }
    _drainQueue();
  }

  // Process queue one-at-a-time so we never exhaust the hardware H.264 decoder pool.
  Future<void> _drainQueue() async {
    if (_queueRunning) return;
    _queueRunning = true;
    while (_initQueue.isNotEmpty) {
      final (index, primary, fallback) = _initQueue.removeAt(0);
      await _initVideo(index, primary, fallback);
    }
    _queueRunning = false;
  }

  // Check file cache only — no network. Returns an initialized controller or null.
  Future<VideoPlayerController?> _fromFileCache(String url) async {
    try {
      final cached = await VideoCacheManager().getFileFromCache(url);
      if (cached == null) return null;
      final file = File(cached.file.path);
      if (!await file.exists()) return null;
      final ctrl = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      return ctrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initVideo(
      int index, String primaryUrl, String? fallbackUrl) async {
    if (_videoControllers.containsKey(index)) return;
    if (_initializingIndices.contains(index)) return;
    _initializingIndices.add(index);
    debugPrint('[SwipeVideo] init idx=$index');

    // ── Stage 1: instant fast-path ────────────────────────────────────────────
    // If the compressed URL is already in the file cache (put there by the home
    // screen), show it right away so the user sees a video immediately instead
    // of a GIF/thumbnail placeholder.
    if (fallbackUrl != null) {
      final fast = await _fromFileCache(fallbackUrl);
      if (fast != null) {
        final keep = {_currentIndex - 1, _currentIndex, _currentIndex + 1};
        if (!keep.contains(index) || !mounted) {
          fast.pause();
          fast.dispose();
        } else {
          if (index == _currentIndex) {
            await fast.play();
          } else {
            fast.pause();
          }
          if (mounted) {
            setState(() => _videoControllers[index] = fast);
            debugPrint('[SwipeVideo] fast-path shown (compressed from cache) idx=$index');
          } else {
            fast.dispose();
          }
        }
      }
    }

    // ── Stage 2: original quality ─────────────────────────────────────────────
    // Load the primary (high-quality) URL. When ready, replace stage-1 ctrl.
    final orig = await initCachedVideoController(primaryUrl, volume: 0);

    _initializingIndices.remove(index);

    if (orig == null) {
      // Primary (original) failed.
      if (_videoControllers.containsKey(index)) {
        // Fast-path ctrl is already showing — keep it, mark done (not failed).
        debugPrint('[SwipeVideo] original failed, keeping compressed idx=$index');
        return;
      }
      // No fast-path and primary failed — try full fallback from network.
      if (fallbackUrl != null) {
        final fallback = await initCachedVideoController(fallbackUrl, volume: 0);
        if (fallback != null) {
          final keep = {_currentIndex - 1, _currentIndex, _currentIndex + 1};
          if (!keep.contains(index) || !mounted) { fallback.dispose(); return; }
          if (index == _currentIndex) {
            fallback.addListener(() => _onCtrlValue(index, fallback));
            await fallback.play();
          } else {
            fallback.pause();
          }
          if (!mounted) { fallback.dispose(); return; }
          setState(() => _videoControllers[index] = fallback);
          return;
        }
      }
      debugPrint('[SwipeVideo] ERROR both failed idx=$index');
      _failedIndices.add(index);
      return;
    }

    // Original loaded — upgrade (or set if no fast-path).
    debugPrint('[SwipeVideo] original ready, upgrading idx=$index');
    final prev = _videoControllers[index]; // might be fast-path ctrl

    final keep = {_currentIndex - 1, _currentIndex, _currentIndex + 1};
    if (!keep.contains(index) || !mounted) {
      orig.pause();
      orig.dispose();
      return;
    }

    if (index == _currentIndex) {
      orig.addListener(() => _onCtrlValue(index, orig));
      await orig.play();
    } else {
      orig.pause();
    }
    if (!mounted) { orig.dispose(); return; }

    setState(() => _videoControllers[index] = orig);
    // Dispose the compressed placeholder after the new frame is painted.
    prev?.pause();
    prev?.dispose();
  }

  void _onCtrlValue(int index, VideoPlayerController ctrl) {
    if (index != _currentIndex) return;
    final v = ctrl.value;
    if (v.hasError) {
      debugPrint('[SwipeVideo] ERROR idx=$index: ${v.errorDescription}');
    } else if (v.isBuffering) {
      debugPrint('[SwipeVideo] BUFFERING idx=$index pos=${v.position}');
    } else if (!v.isPlaying && v.isInitialized && !v.isCompleted) {
      debugPrint('[SwipeVideo] STOPPED (unexpected) idx=$index pos=${v.position}');
    }
  }

  void _onPageChanged(int index, List<TemplateModel> templates) {
    final prev = _currentIndex;
    setState(() => _currentIndex = index);
    debugPrint('[SwipeVideo] page→$index (prev=$prev)');

    // Keep current ±1 — dispose everything else.
    final keep = {index - 1, index, index + 1};
    for (final key in _videoControllers.keys.toList()) {
      if (!keep.contains(key)) {
        debugPrint('[SwipeVideo] dispose stale idx=$key');
        _videoControllers[key]?.pause();
        _videoControllers[key]?.dispose();
        _videoControllers.remove(key);
      }
    }

    // Drop queued items that are no longer in the keep window.
    _initQueue.removeWhere((e) => !keep.contains(e.$1));

    // Play current, pause the rest.
    if (_videoControllers.containsKey(index)) {
      debugPrint('[SwipeVideo] play (cached) idx=$index');
      _videoControllers[index]?.play();
    }
    if (prev != index) _videoControllers[prev]?.pause();

    // Current page gets priority (front of queue), adjacent are low priority.
    final (p, fb) = _videoUrls(templates[index]);
    if (p.isNotEmpty) _enqueueInit(index, p, fb, priority: true);

    if (index - 1 >= 0) {
      final (p2, fb2) = _videoUrls(templates[index - 1]);
      if (p2.isNotEmpty) _enqueueInit(index - 1, p2, fb2);
    }
    if (index + 1 < templates.length) {
      final (p2, fb2) = _videoUrls(templates[index + 1]);
      if (p2.isNotEmpty) _enqueueInit(index + 1, p2, fb2);
    }
  }

  void _initFirstLoad(List<TemplateModel> templates) {
    if (_didInitFirst) return;
    _didInitFirst = true;
    final i = _currentIndex;
    final (p, fb) = _videoUrls(templates[i]);
    if (p.isNotEmpty) _enqueueInit(i, p, fb, priority: true);
    if (i - 1 >= 0) {
      final (p2, fb2) = _videoUrls(templates[i - 1]);
      if (p2.isNotEmpty) _enqueueInit(i - 1, p2, fb2);
    }
    if (i + 1 < templates.length) {
      final (p2, fb2) = _videoUrls(templates[i + 1]);
      if (p2.isNotEmpty) _enqueueInit(i + 1, p2, fb2);
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
          child: Text('Error', style: TextStyle(color: AppColors.textPrimary)),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
              child: Text('No templates',
                  style: TextStyle(color: AppColors.textPrimary)),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initFirstLoad(templates);
          });

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: templates.length,
            onPageChanged: (i) => _onPageChanged(i, templates),
            itemBuilder: (context, index) {
              final t = templates[index];
              final ctrl = _videoControllers[index];

              return _SwipePage(
                template: t,
                controller: ctrl,
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
    required this.onUseTemplate,
    required this.onBack,
  });

  final TemplateModel template;
  final VideoPlayerController? controller;
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
    final ctrl = widget.controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: switches from placeholder → video exactly once, not on every frame.
        RepaintBoundary(
          child: _VideoLayer(
            controller: ctrl,
            template: widget.template,
          ),
        ),

        // Bottom gradient
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

        // Back button
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
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
        ),

        // Report button
        Positioned(
          top: topPad + 12,
          right: 16,
          child: GestureDetector(
            onTap: () => showReportBottomSheet(context, widget.template.id),
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

        // Like button
        Positioned(
          right: 16,
          bottom: bottomPad + 110,
          child: GestureDetector(
            onTap: () {
              _likeAnimCtrl.forward(from: 0);
              ref.read(likesProvider.notifier).toggleLike(widget.template.id);
            },
            child: ScaleTransition(
              scale: _likeScaleAnim,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

        // Title
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

        // Use Template button
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

// Video layer: subscribes to controller and rebuilds exactly once (loading → ready).
// Avoids the 60fps rebuild overhead of ValueListenableBuilder for a playing video.
class _VideoLayer extends StatefulWidget {
  const _VideoLayer({required this.controller, required this.template});
  final VideoPlayerController? controller;
  final TemplateModel template;

  @override
  State<_VideoLayer> createState() => _VideoLayerState();
}

class _VideoLayerState extends State<_VideoLayer> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(_VideoLayer old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      old.controller?.removeListener(_onValue);
      _ready = false;
      _attach(widget.controller);
    }
  }

  void _attach(VideoPlayerController? ctrl) {
    if (ctrl == null) return;
    if (ctrl.value.isInitialized) {
      _ready = true;
    } else {
      ctrl.addListener(_onValue);
    }
  }

  void _onValue() {
    if (!_ready && (widget.controller?.value.isInitialized ?? false)) {
      widget.controller!.removeListener(_onValue);
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (_ready && ctrl != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      );
    }
    return _Placeholder(template: widget.template);
  }
}

// Placeholder: animated GIF if available, otherwise static thumbnail.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.template});
  final TemplateModel template;

  @override
  Widget build(BuildContext context) {
    final gifUrl = template.gifUrl;
    final thumbUrl = template.thumbUrl;

    if (gifUrl != null) {
      return CachedNetworkImage(
        imageUrl: gifUrl,
        cacheManager: AppCacheManager(),
        fit: BoxFit.cover,
        memCacheWidth: 720,
        memCacheHeight: 1280,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => thumbUrl != null
            ? CachedNetworkImage(
                imageUrl: thumbUrl,
                cacheManager: AppCacheManager(),
                fit: BoxFit.cover,
                memCacheWidth: 720,
                memCacheHeight: 1280,
                fadeInDuration: Duration.zero,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Colors.black),
              )
            : const ColoredBox(color: Colors.black),
        errorWidget: (_, __, ___) => thumbUrl != null
            ? CachedNetworkImage(
                imageUrl: thumbUrl,
                cacheManager: AppCacheManager(),
                fit: BoxFit.cover,
                memCacheWidth: 720,
                memCacheHeight: 1280,
                fadeInDuration: Duration.zero,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Colors.black),
              )
            : const ColoredBox(color: Colors.black),
      );
    }

    if (thumbUrl != null) {
      return CachedNetworkImage(
        imageUrl: thumbUrl,
        cacheManager: AppCacheManager(),
        fit: BoxFit.cover,
        memCacheWidth: 720,
        memCacheHeight: 1280,
        fadeInDuration: Duration.zero,
        errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }

    return const ColoredBox(color: Colors.black);
  }
}

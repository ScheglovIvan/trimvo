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

class TemplateDetailScreen extends ConsumerStatefulWidget {
  const TemplateDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoError = false;

  late AnimationController _likeAnimCtrl;
  late Animation<double> _likeScaleAnim;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.4)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 1.4, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 1),
    ]).animate(_likeAnimCtrl);
  }

  Future<void> _initVideo(String url) async {
    final ctrl = await initCachedVideoController(url, volume: 1.0);
    if (!mounted) {
      ctrl?.pause();
      ctrl?.dispose();
      return;
    }
    if (ctrl == null) {
      setState(() => _videoError = true);
    } else {
      setState(() {
        _controller = ctrl;
        _videoReady = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
    }
  }

  @override
  void deactivate() {
    _controller?.pause();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (_videoReady) _controller?.play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _likeAnimCtrl.dispose();
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(templateDetailProvider(widget.id));
    final likedIds = ref.watch(likesProvider);
    final isLiked = likedIds.contains(widget.id);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: templateAsync.when(
        loading: () =>
            _buildBody(context, null, isLiked: isLiked, bottomPad: bottomPad, isLoading: true),
        error: (_, __) =>
            _buildBody(context, null, isLiked: isLiked, bottomPad: bottomPad),
        data: (template) {
          if (_controller == null && !_videoError && template.previewUrl != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _controller == null && !_videoError) {
                _initVideo(template.previewUrl!);
              }
            });
          }
          return _buildBody(context, template,
              isLiked: isLiked, bottomPad: bottomPad);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TemplateModel? template, {
    required bool isLiked,
    required double bottomPad,
    bool isLoading = false,
  }) {
    final thumbUrl = template?.thumbUrl;
    final title = template?.title ?? '';
    final templateId = template?.id ?? widget.id;
    final apiLikes = template?.likes ?? 0;
    final displayLikes = apiLikes + (isLiked ? 1 : 0);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: thumb always, video on top when ready
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [
              ...previous,
              if (current != null) current,
            ],
          ),
          child: _videoReady && _controller != null
              ? SizedBox.expand(
                  key: const ValueKey('video'),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('thumb'),
                  child: _buildThumbLayer(thumbUrl),
                ),
        ),

        // Bottom gradient
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
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

        // Loading indicator
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.accentPurple),
          ),

        // Back button — top: 50
        Positioned(
          top: 50,
          left: 16,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),

        // Report button — top: 50
        Positioned(
          top: 50,
          right: 16,
          child: GestureDetector(
            onTap: () => showReportBottomSheet(context, templateId),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),

        // Like column — right side, above button
        Positioned(
          right: 16,
          bottom: 110 + bottomPad,
          child: GestureDetector(
            onTap: () {
              _likeAnimCtrl.forward(from: 0);
              ref
                  .read(likesProvider.notifier)
                  .toggleLike(templateId);
            },
            child: ScaleTransition(
              scale: _likeScaleAnim,
              child: SizedBox(
                width: 56,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.redAccent : Colors.white,
                        size: 22,
                      ),
                      Text(
                        _formatLikes(displayLikes),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Title — left side, above button
        if (title.isNotEmpty)
          Positioned(
            left: 16,
            right: 80,
            bottom: 110 + bottomPad,
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Use Template button
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: () => context.push(
                  '/upload?templateId=${Uri.encodeComponent(templateId)}',
                ),
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
          ),
        ),
      ],
    );
  }

  String _formatLikes(int likes) {
    if (likes >= 1000) return '${(likes / 1000).floor()}k';
    return '$likes';
  }

  Widget _buildThumbLayer(String? thumbUrl) {
    return SizedBox.expand(
      child: thumbUrl != null
          ? CachedNetworkImage(
              imageUrl: thumbUrl,
              cacheManager: AppCacheManager(),
              fit: BoxFit.cover,
              memCacheWidth: 720,
              memCacheHeight: 1280,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
            )
          : const ColoredBox(color: Colors.black),
    );
  }
}

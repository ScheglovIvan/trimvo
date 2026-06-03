import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/shared/utils/video_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class WorkVideoScreen extends StatefulWidget {
  const WorkVideoScreen({
    super.key,
    required this.videoUrl,
    this.thumbUrl,
  });

  final String videoUrl;
  final String? thumbUrl;

  @override
  State<WorkVideoScreen> createState() => _WorkVideoScreenState();
}

class _WorkVideoScreenState extends State<WorkVideoScreen> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoError = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.videoUrl;
    if (url.isEmpty) {
      if (mounted) setState(() => _videoError = true);
      return;
    }
    final path = url.split('?').first;
    if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) return;

    // Используем ту же логику кеширования что и home screen, но с volume 1.0
    final ctrl = await initCachedVideoController(url, volume: 1.0);
    if (!mounted) {
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

  Future<void> _share() async {
    final url = widget.videoUrl;
    if (url.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final resp = await http.get(Uri.parse(url));
      final tmp = await getTemporaryDirectory();
      final filePath = '${tmp.path}/share_work.mp4';
      await File(filePath).writeAsBytes(resp.bodyBytes);
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Check out my Trimvo video!',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share video')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen media layer
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, if (current != null) current],
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
                    child: _buildThumb(),
                  ),
          ),

          // Loading indicator
          if (!_videoReady && !_videoError)
            const Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            ),

          // Error state
          if (_videoError)
            const Center(
              child: Icon(Icons.error_outline, color: Colors.white54, size: 64),
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

          // Back button — top left
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

          // Share button — right side, like the like button in TemplateDetailScreen
          Positioned(
            right: 16,
            bottom: 40 + bottomPad,
            child: GestureDetector(
              onTap: _share,
              child: SizedBox(
                width: 56,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _sharing
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.share,
                                color: Colors.white, size: 22),
                            const SizedBox(height: 2),
                            Text(
                              'Share',
                              style: GoogleFonts.inter(
                                fontSize: 10,
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
        ],
      ),
    );
  }

  Widget _buildThumb() {
    final url = widget.thumbUrl;
    return SizedBox.expand(
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            )
          : const ColoredBox(color: Colors.black),
    );
  }
}

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
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

class _WorkVideoScreenState extends State<WorkVideoScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoError = false;
  bool _sharing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed && _videoReady) {
      _controller?.play();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.videoUrl;
    if (url.isEmpty) {
      if (mounted) setState(() => _videoError = true);
      return;
    }
    final path = url.split('?').first.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) return;

    try {
      final opts = VideoPlayerOptions(mixWithOthers: true);
      VideoPlayerController ctrl;

      // Use cached file if available (avoids any network latency).
      // Falls back to streaming for first-time or cache-miss.
      final cached = await VideoCacheManager().getFileFromCache(url);
      if (cached != null && await cached.file.exists()) {
        ctrl = VideoPlayerController.file(cached.file, videoPlayerOptions: opts);
      } else {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: opts);
      }

      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(1.0);
      if (!mounted) { ctrl.dispose(); return; }
      setState(() { _controller = ctrl; _videoReady = true; });
      ctrl.play();
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  Future<void> _streamToFile(String url, String filePath) async {
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      final sink = File(filePath).openWrite();
      await response.stream.pipe(sink);
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }

  Future<void> _share() async {
    final url = widget.videoUrl;
    if (url.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final tmp = await getTemporaryDirectory();
      final filePath = '${tmp.path}/share_work.mp4';
      await _streamToFile(url, filePath);
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

  Future<void> _save() async {
    final url = widget.videoUrl;
    if (url.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final tmp = await getTemporaryDirectory();
      final fileName = 'trimvo_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${tmp.path}/$fileName';
      await _streamToFile(url, filePath);
      final result = await SaverGallery.saveFile(
        file: filePath,
        name: fileName,
        androidRelativePath: 'Movies/Trimvo',
        androidExistNotSave: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.isSuccess ? 'Saved to gallery' : 'Could not save video')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save video')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.pause();
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
                      fit: BoxFit.contain,
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
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // Top gradient
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // Top bar: back + share
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
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

                    const Spacer(),

                    // Share button — top right
                    GestureDetector(
                      onTap: _share,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: _sharing
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                ),
                              )
                            : const Icon(Icons.ios_share,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom: large Save button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, bottomPad + 16),
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B2FD9), Color(0xFF9B59F5)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _saving
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Save',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
              cacheManager: AppCacheManager(),
              fit: BoxFit.contain,
              memCacheWidth: 720,
              memCacheHeight: 1280,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            )
          : const ColoredBox(color: Colors.black),
    );
  }
}

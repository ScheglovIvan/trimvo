import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/shared/utils/video_utils.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, this.resultUrl, this.originalUrl});

  final String? resultUrl;
  final String? originalUrl;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _videoInitialized = false;
  bool _videoError = false;
  bool _isPlaying = false;
  bool _downloading = false;
  bool _sharing = false;

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
    } else if (state == AppLifecycleState.resumed && _isPlaying) {
      _controller?.play();
    }
  }

  Future<void> _initVideo() async {
    // Prefer full-quality original; fall back to preview
    final url = widget.originalUrl ?? widget.resultUrl;
    if (url == null || url.isEmpty) return;

    // Strip query params before extension check (presigned URLs have ?token=...)
    final path = url.split('?').first;
    if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
      return;
    }

    try {
      final ctrl = await initCachedVideoController(url);
      if (ctrl == null) {
        if (mounted) setState(() => _videoError = true);
        return;
      }
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _videoInitialized = true;
          _isPlaying = true;
        });
      } else {
        ctrl.pause();
        ctrl.dispose();
      }
    } catch (e) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        _isPlaying = false;
      } else {
        ctrl.play();
        _isPlaying = true;
      }
    });
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

  Future<void> _downloadVideo() async {
    final url = widget.originalUrl ?? widget.resultUrl;
    if (url == null || _downloading) return;

    setState(() => _downloading = true);
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
          SnackBar(
            content: Text(result.isSuccess ? 'Saved to gallery' : 'Could not save video'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareVideo() async {
    final url = widget.originalUrl ?? widget.resultUrl;
    if (url == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final tmp = await getTemporaryDirectory();
      final path = '${tmp.path}/share_video.mp4';
      await _streamToFile(url, path);
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Check out my Trimvo video!',
      );
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  bool get _isImage {
    final url = (widget.originalUrl ?? widget.resultUrl ?? '').split('?').first;
    return url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Медиа контент ───────────────────────────────────────────
          if ((widget.resultUrl == null || widget.resultUrl!.isEmpty) &&
              (widget.originalUrl == null || widget.originalUrl!.isEmpty))
            const Center(
              child: Icon(Icons.error_outline, color: Colors.white54, size: 64),
            )
          else if (_isImage)
            SizedBox.expand(
              child: CachedNetworkImage(
                imageUrl: widget.originalUrl ?? widget.resultUrl!,
                fit: BoxFit.cover,
                cacheManager: AppCacheManager(),
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: AppColors.accentPurple),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            )
          else if (_videoError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load video',
                    style:
                        GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.resultUrl ?? '',
                    style:
                        GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_videoInitialized && _controller != null)
            GestureDetector(
              onTap: _togglePlay,
              behavior: HitTestBehavior.opaque,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            ),

          // ── Play/Pause оверлей ──────────────────────────────────────
          if (_videoInitialized && !_isPlaying)
            const Center(
              child:
                  Icon(Icons.play_circle_fill, color: Colors.white70, size: 72),
            ),

          // ── Top bar ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Result',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // ── Bottom actions ──────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Сохранить
                  Expanded(
                    child: GestureDetector(
                      onTap: _downloading ? null : _downloadVideo,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: _downloading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.download,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Save',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Поделиться
                  Expanded(
                    child: GestureDetector(
                      onTap: _shareVideo,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.share,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Share',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Создать ещё
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.accentPurpleLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'More',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
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
        ],
      ),
    );
  }
}

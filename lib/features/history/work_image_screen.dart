import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class WorkImageScreen extends StatefulWidget {
  const WorkImageScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<WorkImageScreen> createState() => _WorkImageScreenState();
}

class _WorkImageScreenState extends State<WorkImageScreen> {
  late final PageController _pageCtrl;
  late int _currentPage;
  bool _sharing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<String> _streamToFile(String url, String filePath) async {
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      final sink = File(filePath).openWrite();
      await response.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      return filePath;
    } finally {
      client.close();
    }
  }

  Future<void> _share() async {
    final url = widget.imageUrls[_currentPage];
    if (url.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final tmp = await getTemporaryDirectory();
      final path = '${tmp.path}/share_image_$_currentPage.jpg';
      await _streamToFile(url, path);
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Check out my Trimvo creation!',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share image')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _save() async {
    final url = widget.imageUrls[_currentPage];
    if (url.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final tmp = await getTemporaryDirectory();
      final fileName = 'trimvo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tmp.path}/$fileName';
      await _streamToFile(url, filePath);
      final result = await SaverGallery.saveFile(
        file: filePath,
        name: fileName,
        androidRelativePath: 'Pictures/Trimvo',
        androidExistNotSave: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.isSuccess ? 'Saved to gallery' : 'Could not save image')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save image')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final hasMultiple = widget.imageUrls.length > 1;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/history');
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen swipeable images ─────────────────────────────
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.imageUrls.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrls[i],
                  cacheManager: AppCacheManager(),
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) =>
                      const ColoredBox(color: Colors.black),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white30, size: 56),
                  ),
                ),
              ),
            ),

            // ── Top bar: back | counter | share ─────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => context.go('/history'),
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

                        // Centered X / N counter
                        Expanded(
                          child: hasMultiple
                              ? Center(
                                  child: Text(
                                    '${_currentPage + 1} / ${widget.imageUrls.length}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        // Share button (Telegram-style forward arrow)
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
                                          strokeWidth: 2,
                                          color: Colors.white),
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
            ),

            // ── Bottom: Save button + dot indicators ─────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                padding:
                    EdgeInsets.fromLTRB(16, 32, 16, bottomPad + 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Save button
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        height: 56,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6B2FD9),
                              Color(0xFF9B59F5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _saving
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                      size: 22),
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

                    // Dot indicators (only when multiple images)
                    if (hasMultiple) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.imageUrls.length,
                          (i) {
                            final isActive = i == _currentPage;
                            return GestureDetector(
                              onTap: () => _pageCtrl.animateToPage(
                                i,
                                duration:
                                    const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              ),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                width: isActive ? 20 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Left arrow ───────────────────────────────────────────────
            if (hasMultiple && _currentPage > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),

            // ── Right arrow ──────────────────────────────────────────────
            if (hasMultiple &&
                _currentPage < widget.imageUrls.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/widgets/app_background.dart';
import 'package:trimvo/models/job_model.dart';
import 'package:trimvo/models/template_model.dart';
import 'package:trimvo/providers/jobs_provider.dart';
import 'package:trimvo/providers/likes_provider.dart';
import 'package:trimvo/providers/templates_provider.dart';
import 'package:trimvo/shared/utils/video_utils.dart';
import 'package:trimvo/shared/widgets/app_bottom_nav.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:video_player/video_player.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: AppBottomNav(
          currentIndex: 1,
          onTap: (i) {
            if (i == 0) context.go('/home');
          },
        ),
        body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'History',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accentPurple,
              indicatorWeight: 2,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: 'My Works'),
                Tab(text: 'Favorites'),
                Tab(text: 'Recently'),
              ],
            ),

            const Divider(height: 1, color: AppColors.backgroundCard),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _MyWorksTab(),
                  _FavoritesTab(),
                  _ComingSoonTab(icon: Icons.history_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Works tab
// ─────────────────────────────────────────────────────────────────────────────

class _MyWorksTab extends ConsumerStatefulWidget {
  const _MyWorksTab();

  @override
  ConsumerState<_MyWorksTab> createState() => _MyWorksTabState();
}

class _MyWorksTabState extends ConsumerState<_MyWorksTab>
    with WidgetsBindingObserver {
  bool _loading = true;
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, VideoPlayerController> _videoControllers = {};
  Set<int> _activeIndices = {0, 1};
  List<JobModel> _sortedJobs = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    _loadJobs();
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
      for (final i in _activeIndices) {
        _videoControllers[i]?.play();
      }
    }
  }

  Future<void> _loadJobs() async {
    try {
      await ref.read(jobsProvider.notifier).getUserJobs();
      // Refresh full details for done image jobs — list endpoint omits result_urls
      await ref.read(jobsProvider.notifier).fetchImageJobDetails();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _onScroll() {
    if (!mounted || !_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset;
    final size = MediaQuery.of(context).size;
    final cardW = (size.width - 44) / 2;
    // Approximate row height using the average aspect ratio of loaded jobs
    final avgRatio = _sortedJobs.isEmpty
        ? 9 / 16
        : _sortedJobs.fold<double>(0, (s, j) => s + j.cardAspectRatio) /
            _sortedJobs.length;
    final cardH = cardW / avgRatio;

    int centerRow;
    if (offset < 30) {
      centerRow = 0;
    } else {
      final centerOffset = offset + size.height / 2;
      centerRow = ((centerOffset - 16) / (cardH + 12)).round().clamp(0, 999);
    }
    final newActive = {centerRow * 2, centerRow * 2 + 1};

    if (newActive == _activeIndices) return;

    for (final i in _activeIndices) {
      if (!newActive.contains(i)) {
        _videoControllers[i]?.pause();
        _videoControllers[i]?.dispose();
        _videoControllers.remove(i);
      }
    }

    setState(() => _activeIndices = newActive);

    // Lookahead: предзагрузить следующую строку (как в home screen)
    final nextRow = centerRow + 1;
    for (final i in [nextRow * 2, nextRow * 2 + 1]) {
      if (i < _sortedJobs.length) {
        final url = _sortedJobs[i].playbackUrl;
        if (url != null && url.isNotEmpty) {
          _initAndPlayController(i, url);
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, String jobId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete video?',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(jobsProvider.notifier).deleteJob(jobId);
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Failed to delete video')),
          );
        }
      }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPurple),
      );
    }

    final jobs = ref.watch(jobsProvider).jobs;
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined,
                color: AppColors.textHint, size: 56),
            const SizedBox(height: 16),
            Text(
              'No videos yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a video from a template',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = [...jobs]..sort((a, b) {
        int order(JobModel j) {
          if (j.status == 'processing') return 0;
          if (j.status == 'queued') return 1;
          return 2;
        }
        return order(a).compareTo(order(b));
      });

    // Синхронизируем кеш отсортированного списка для lookahead в _onScroll
    if (_sortedJobs.length != sorted.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _sortedJobs = sorted);
      });
    }

    if (_activeIndices.isEmpty && sorted.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final initialActive = {0, if (sorted.length > 1) 1};
        setState(() {
          _activeIndices = initialActive;
          _sortedJobs = sorted;
        });
        // Preload строка 0 + lookahead строка 1 (как home screen)
        for (var i = 0; i < sorted.length && i < 4; i++) {
          final url = sorted[i].playbackUrl;
          if (url != null && url.isNotEmpty) _initAndPlayController(i, url);
        }
      });
    }

    return MasonryGridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final job = sorted[i];
        return AspectRatio(
          aspectRatio: job.cardAspectRatio,
          child: _JobCard(
            job: job,
            controller: _videoControllers[i],
            isActive: _activeIndices.contains(i),
            onActivate: () {
              final url = job.playbackUrl;
              if (url != null && url.isNotEmpty) {
                _initAndPlayController(i, url);
              }
            },
            onDelete: () => _confirmDelete(context, job.id),
          ),
        );
      },
    );
  }
}

class _JobCard extends StatefulWidget {
  const _JobCard({
    required this.job,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
    this.controller,
  });

  final JobModel job;
  final VideoPlayerController? controller;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  @override
  void initState() {
    super.initState();
    if (widget.isActive) widget.onActivate();
  }

  @override
  void didUpdateWidget(_JobCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) widget.onActivate();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final ctrl = widget.controller;
    final videoReady = ctrl != null && ctrl.value.isInitialized;
    final isProcessing = job.status == 'processing' || job.status == 'queued';

    final isImage = job.isImageJob;

    return GestureDetector(
      onTap: job.isDone
          ? () {
              if (isImage) {
                final urls = job.imageUrls.isNotEmpty
                    ? job.imageUrls
                    : (job.resultUrl != null ? [job.resultUrl!] : <String>[]);
                context.push('/work-image', extra: <String, dynamic>{
                  'imageUrls': urls,
                  'initialIndex': 0,
                });
              } else {
                context.push('/work-video', extra: <String, String?>{
                  'videoUrl': job.fullUrl ?? job.resultUrl ?? '',
                  'thumbUrl': job.thumbUrl,
                });
              }
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: background
            const ColoredBox(color: AppColors.backgroundCard),

            // Layer 2: content (image result or video thumb)
            if (isImage && job.primaryImageUrl != null)
              CachedNetworkImage(
                imageUrl: job.primaryImageUrl!,
                cacheManager: AppCacheManager(),
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) =>
                    const ColoredBox(color: AppColors.backgroundCard),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: AppColors.backgroundCard),
              )
            else if (job.thumbUrl != null)
              CachedNetworkImage(
                imageUrl: job.thumbUrl!,
                cacheManager: AppCacheManager(),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) =>
                    const ColoredBox(color: AppColors.backgroundCard),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: AppColors.backgroundCard),
              ),

            // Layer 3: preview video (video jobs only)
            if (!isImage && videoReady)
              RepaintBoundary(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: ctrl.value.size.width,
                      height: ctrl.value.size.height,
                      child: VideoPlayer(ctrl),
                    ),
                  ),
                ),
              ),

            // Layer 4: processing overlay
            if (isProcessing) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x55000000), Color(0xCC000000)],
                    stops: [0.3, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCard.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accentPurple.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.accentPurpleLight,
                                value: job.progress > 0
                                    ? job.progress / 100.0
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              job.status == 'queued'
                                  ? 'In Queue'
                                  : job.progress > 0
                                      ? 'Generating ${job.progress}%'
                                      : 'Generating...',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (job.progress > 0)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        child: LinearProgressIndicator(
                          value: job.progress / 100.0,
                          minHeight: 3,
                          backgroundColor: AppColors.backgroundCard,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accentPurpleLight,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Layer 5: error overlay
            if (job.isFailed) ...[
              Container(color: Colors.black.withOpacity(0.6)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 32),
                    const SizedBox(height: 8),
                    Text('Failed',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.redAccent)),
                  ],
                ),
              ),
            ],

            // Layer 6: play icon for video (while video loading)
            if (job.isDone && !isImage && !videoReady)
              const Center(
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white54, size: 40),
              ),

            // Type badge — bottom left (done jobs only)
            if (job.isDone)
              Positioned(
                left: 8,
                bottom: 8,
                child: _TypeBadge(job: job),
              ),

            // Delete button — top right
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: widget.onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type badge
// ─────────────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;

    if (job.isImageJob) {
      icon = Icons.image_outlined;
      label = job.imageUrls.length > 1
          ? 'Photo (${job.imageUrls.length})'
          : 'Photo';
    } else {
      icon = Icons.videocam_outlined;
      label = 'Video';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coming Soon stub
// ─────────────────────────────────────────────────────────────────────────────

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textHint, size: 56),
          const SizedBox(height: 16),
          Text(
            'Coming soon',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Favorites tab
// ─────────────────────────────────────────────────────────────────────────────

class _FavoritesTab extends ConsumerStatefulWidget {
  const _FavoritesTab();

  @override
  ConsumerState<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<_FavoritesTab>
    with WidgetsBindingObserver {
  final ScrollController _scrollCtrl = ScrollController();
  final Map<String, VideoPlayerController> _videoControllers = {};
  Set<String> _activeIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
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
      for (final id in _activeIds) {
        _videoControllers[id]?.play();
      }
    }
  }

  void _activateId(String id) {
    final async = ref.read(templateDetailProvider(id));
    async.whenData((template) {
      final url = template.previewCompressedUrl ?? template.previewUrl;
      if (url != null) _initVideo(id, url);
    });
  }

  void _onScroll() {
    if (!mounted || !_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset;
    final size = MediaQuery.of(context).size;
    final cardW = (size.width - 44) / 2;
    final cardH = cardW * (4 / 3) + 12;

    final centerOffset = offset + size.height / 2;
    final centerRow = ((centerOffset - 16) / cardH).round().clamp(0, 999);

    final likedIds = ref.read(likesProvider).toList();
    final newActiveIndices = [centerRow * 2, centerRow * 2 + 1]
        .where((i) => i < likedIds.length)
        .toList();
    final newActiveIds = newActiveIndices.map((i) => likedIds[i]).toSet();

    if (newActiveIds == _activeIds) return;

    for (final id in _activeIds) {
      if (!newActiveIds.contains(id)) {
        _videoControllers[id]?.pause();
        _videoControllers[id]?.dispose();
        _videoControllers.remove(id);
      }
    }

    final oldActiveIds = Set<String>.from(_activeIds);
    setState(() => _activeIds = newActiveIds);

    for (final id in newActiveIds) {
      if (!oldActiveIds.contains(id)) _activateId(id);
    }
  }

  Future<void> _initVideo(String id, String url) async {
    if (_videoControllers.containsKey(id)) return;
    final ctrl = await initCachedVideoController(url);
    if (ctrl == null) return;
    if (mounted) {
      setState(() => _videoControllers[id] = ctrl);
    } else {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final likedIds = ref.watch(likesProvider).toList();

    if (likedIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border,
                color: AppColors.textHint, size: 56),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap ❤️ on a template to save it here',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    if (_activeIds.isEmpty && likedIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final initialIds = {
            likedIds[0],
            if (likedIds.length > 1) likedIds[1],
          };
          setState(() => _activeIds = initialIds);
          for (final id in initialIds) {
            _activateId(id);
          }
        }
      });
    }

    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _FavoriteCard(
                id: likedIds[i],
                isActive: _activeIds.contains(likedIds[i]),
                controller: _videoControllers[likedIds[i]],
              ),
              childCount: likedIds.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single favorite card
// ─────────────────────────────────────────────────────────────────────────────

class _FavoriteCard extends ConsumerWidget {
  const _FavoriteCard({
    required this.id,
    this.isActive = false,
    this.controller,
  });

  final String id;
  final bool isActive;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(templateDetailProvider(id));

    return async.when(
      loading: () => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: const ColoredBox(color: AppColors.backgroundCard),
      ),
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(likesProvider.notifier).removeDeadId(id);
        });
        return const SizedBox.shrink();
      },
      data: (template) => _buildCard(context, ref, template),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, TemplateModel template) {
    final videoReady = controller != null && controller!.value.isInitialized;

    return GestureDetector(
      onTap: () =>
          context.push('/template/${Uri.encodeComponent(template.id)}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: thumb
            if (template.thumbUrl != null)
              CachedNetworkImage(
                imageUrl: template.thumbUrl!,
                cacheManager: AppCacheManager(),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) =>
                    const ColoredBox(color: AppColors.backgroundCard),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: AppColors.backgroundCard),
              )
            else
              const ColoredBox(color: AppColors.backgroundCard),

            // Layer 2: GIF (активна, видео ещё не готово)
            if (template.gifUrl != null)
              AnimatedOpacity(
                opacity: isActive && !videoReady ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: RepaintBoundary(
                  child: CachedNetworkImage(
                    imageUrl: template.gifUrl!,
                    cacheManager: AppCacheManager(),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Layer 3: видео (когда готово)
            if (videoReady)
              RepaintBoundary(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  ),
                ),
              ),

            // Кнопка unlike
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: () =>
                    ref.read(likesProvider.notifier).toggleLike(template.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 18,
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

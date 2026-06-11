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
import 'package:trimvo/services/api_service.dart';
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
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (mounted && _tabController.index != _activeTabIndex) {
      setState(() => _activeTabIndex = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
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
              ],
            ),

            const Divider(height: 1, color: AppColors.backgroundCard),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MyWorksTab(isActive: _activeTabIndex == 0),
                  _FavoritesTab(isActive: _activeTabIndex == 1),
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
  const _MyWorksTab({required this.isActive});

  final bool isActive;

  @override
  ConsumerState<_MyWorksTab> createState() => _MyWorksTabState();
}

class _MyWorksTabState extends ConsumerState<_MyWorksTab>
    with WidgetsBindingObserver {
  bool _loading = true;
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Set<int> _initializingIndices = {};
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
  void didUpdateWidget(_MyWorksTab old) {
    super.didUpdateWidget(old);
    if (!widget.isActive && old.isActive) {
      for (final ctrl in _videoControllers.values) { ctrl.pause(); }
    } else if (widget.isActive && !old.isActive) {
      for (final i in _activeIndices) { _videoControllers[i]?.play(); }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    for (final ctrl in _videoControllers.values) {
      ctrl.pause();
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
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      for (final i in _activeIndices) {
        _videoControllers[i]?.play();
      }
    }
  }

  Future<void> _loadJobs() async {
    try {
      await ref.read(jobsProvider.notifier).getUserJobs();
      await ref.read(jobsProvider.notifier).fetchImageJobDetails();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
    final jobs = ref.read(jobsProvider).jobs;
    for (final job in jobs.take(4)) {
      final url = job.playbackUrl;
      if (url != null && url.isNotEmpty && !job.isImageJob) prefetchVideo(url);
    }
  }

  Future<void> _loadMore() async {
    await ref.read(jobsProvider.notifier).loadMoreJobs();
    if (mounted) {
      await ref.read(jobsProvider.notifier).fetchImageJobDetails();
    }
  }

  void _onScroll() {
    if (!mounted || !_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset;
    final size = MediaQuery.of(context).size;
    final cardW = (size.width - 44) / 2;
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

    if (newActive != _activeIndices) {
      for (final i in _activeIndices) {
        if (!newActive.contains(i)) {
          _videoControllers[i]?.pause();
          _videoControllers[i]?.dispose();
          _videoControllers.remove(i);
        }
      }
      setState(() => _activeIndices = newActive);
    }

    // Load next page when within 400px of the bottom
    final pos = _scrollCtrl.position;
    if (pos.pixels > pos.maxScrollExtent - 400) {
      final jobsState = ref.read(jobsProvider);
      if (jobsState.hasMore && !jobsState.isLoadingMore) _loadMore();
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
    if (_initializingIndices.contains(index)) return;
    _initializingIndices.add(index);
    final ctrl = await initCachedVideoController(url);
    _initializingIndices.remove(index);
    if (ctrl == null) return;
    // Re-check after await: widget may be gone or index may be scrolled away.
    if (!mounted || !_activeIndices.contains(index)) {
      ctrl.pause();
      ctrl.dispose();
      return;
    }
    setState(() => _videoControllers[index] = ctrl);
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

    final jobsState = ref.watch(jobsProvider);
    final sorted = [...jobs]..sort((a, b) {
        int statusOrder(JobModel j) {
          if (j.status == 'processing') return 0;
          if (j.status == 'queued') return 1;
          return 2;
        }
        final statusCmp = statusOrder(a).compareTo(statusOrder(b));
        if (statusCmp != 0) return statusCmp;
        // Within the same group — newest first
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    // _sortedJobs is only read in _onScroll for height estimation — update directly,
    // no setState needed since it doesn't affect the widget tree output.
    if (_sortedJobs.length != sorted.length) {
      _sortedJobs = sorted;
    }

    if (_activeIndices.isEmpty && sorted.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sortedJobs = sorted;
        setState(() => _activeIndices = {0, if (sorted.length > 1) 1});
        for (var i = 0; i < sorted.length && i < 4; i++) {
          final url = sorted[i].playbackUrl;
          if (url != null && url.isNotEmpty) _initAndPlayController(i, url);
        }
      });
    }

    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverMasonryGrid(
            gridDelegate:
                const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            delegate: SliverChildBuilderDelegate(
              (context, i) {
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
              childCount: sorted.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: jobsState.isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentPurple,
                    ),
                  ),
                )
              : const SizedBox(height: 24),
        ),
      ],
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
  bool _opening = false;

  Future<void> _openImageJob(BuildContext context) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final fresh = await ApiService.getJobStatus(widget.job.id);
      final freshJob = JobModel.fromJson(fresh);
      final urls = freshJob.imageUrls.isNotEmpty
          ? freshJob.imageUrls
          : (freshJob.resultUrl != null ? [freshJob.resultUrl!] : <String>[]);
      if (urls.isEmpty) return;
      if (context.mounted) {
        final ar = freshJob.aspectRatio ?? widget.job.aspectRatio;
        context.push('/work-image', extra: <String, dynamic>{
          'imageUrls': urls,
          'initialIndex': 0,
          'fitCover': ar == '3:4' || ar == '9:16',
        });
      }
    } catch (_) {
      // fallback: use cached URLs even if expired
      final urls = widget.job.imageUrls.isNotEmpty
          ? widget.job.imageUrls
          : (widget.job.resultUrl != null ? [widget.job.resultUrl!] : <String>[]);
      if (urls.isNotEmpty && context.mounted) {
        final ar = widget.job.aspectRatio;
        context.push('/work-image', extra: <String, dynamic>{
          'imageUrls': urls,
          'initialIndex': 0,
          'fitCover': ar == '3:4' || ar == '9:16',
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

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
                _openImageJob(context);
              } else {
                context.push('/work-video', extra: <String, dynamic>{
                  'videoUrl': job.fullUrl ?? job.resultUrl ?? '',
                  'thumbUrl': job.thumbUrl,
                  'fitCover': job.jobType == 'template',
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
                fit: BoxFit.cover,
                memCacheWidth: 350,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) =>
                    const ColoredBox(color: AppColors.backgroundCard),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.image_outlined,
                      color: AppColors.textHint, size: 40),
                ),
              )
            else if (isImage)
              const Center(
                child: Icon(Icons.image_outlined,
                    color: AppColors.textHint, size: 40),
              )
            else if (job.thumbUrl != null)
              CachedNetworkImage(
                imageUrl: job.thumbUrl!,
                cacheManager: AppCacheManager(),
                fit: BoxFit.cover,
                memCacheWidth: 350,
                memCacheHeight: 630,
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

            // Loading overlay while fetching fresh image URL
            if (_opening)
              const ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
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
// Favorites tab
// ─────────────────────────────────────────────────────────────────────────────

class _FavoritesTab extends ConsumerStatefulWidget {
  const _FavoritesTab({required this.isActive});

  final bool isActive;

  @override
  ConsumerState<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<_FavoritesTab>
    with WidgetsBindingObserver {
  final ScrollController _scrollCtrl = ScrollController();
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Set<String> _initializingIds = {};
  Set<String> _activeIds = {};
  int _visibleCount = 20;
  bool _didInitActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_FavoritesTab old) {
    super.didUpdateWidget(old);
    if (!widget.isActive && old.isActive) {
      for (final ctrl in _videoControllers.values) { ctrl.pause(); }
    } else if (widget.isActive && !old.isActive) {
      for (final id in _activeIds) { _videoControllers[id]?.play(); }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    for (final ctrl in _videoControllers.values) {
      ctrl.pause();
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
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
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
    final cardH = cardW * (16 / 9) + 12;

    final centerOffset = offset + size.height / 2;
    final centerRow = ((centerOffset - 16) / cardH).round().clamp(0, 999);

    final allIds = ref.read(likesProvider).toList();
    final visibleIds = allIds.take(_visibleCount).toList();

    final newActiveIndices = [centerRow * 2, centerRow * 2 + 1]
        .where((i) => i < visibleIds.length)
        .toList();
    final newActiveIds = newActiveIndices.map((i) => visibleIds[i]).toSet();

    if (newActiveIds != _activeIds) {
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

    // Load more items when within 400px of the bottom
    final pos = _scrollCtrl.position;
    if (pos.pixels > pos.maxScrollExtent - 400 &&
        _visibleCount < allIds.length) {
      setState(() {
        _visibleCount = (_visibleCount + 20).clamp(0, allIds.length);
      });
    }
  }

  Future<void> _initVideo(String id, String url) async {
    if (_videoControllers.containsKey(id)) return;
    if (_initializingIds.contains(id)) return;
    _initializingIds.add(id);
    final ctrl = await initCachedVideoController(url);
    _initializingIds.remove(id);
    if (ctrl == null) return;
    // Re-check after await: widget may be gone or id may be scrolled away.
    if (!mounted || !_activeIds.contains(id)) {
      ctrl.pause();
      ctrl.dispose();
      return;
    }
    setState(() => _videoControllers[id] = ctrl);
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

    final visibleIds = likedIds.take(_visibleCount).toList();
    final hasMore = _visibleCount < likedIds.length;

    if (!_didInitActive && _activeIds.isEmpty && visibleIds.isNotEmpty) {
      _didInitActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final initialIds = {
            visibleIds[0],
            if (visibleIds.length > 1) visibleIds[1],
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 9 / 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _FavoriteCard(
                id: visibleIds[i],
                isActive: _activeIds.contains(visibleIds[i]),
                controller: _videoControllers[visibleIds[i]],
              ),
              childCount: visibleIds.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: hasMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentPurple,
                    ),
                  ),
                )
              : const SizedBox(height: 24),
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
                memCacheWidth: 350,
                memCacheHeight: 630,
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
                    memCacheWidth: 350,
                    memCacheHeight: 630,
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

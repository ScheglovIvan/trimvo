import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/models/job_model.dart';
import 'package:trimvo/providers/jobs_provider.dart';
import 'package:trimvo/shared/widgets/app_bottom_nav.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

class GeneratingScreen extends ConsumerStatefulWidget {
  const GeneratingScreen({
    super.key,
    this.jobId,
    this.backgroundImagePath,
    this.jobType,
  });

  final String? jobId;
  final String? backgroundImagePath;
  /// "image" for image jobs, null/other for video jobs.
  final String? jobType;

  @override
  ConsumerState<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends ConsumerState<GeneratingScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.jobId != null && widget.jobId!.isNotEmpty) {
      return _PollingView(
        jobId: widget.jobId!,
        backgroundImagePath: widget.backgroundImagePath,
        jobType: widget.jobType,
      );
    }
    return const _HistoryView();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// POLLING VIEW
// ═══════════════════════════════════════════════════════════════════════════════

class _PollingView extends ConsumerStatefulWidget {
  const _PollingView({
    required this.jobId,
    this.backgroundImagePath,
    this.jobType,
  });

  final String jobId;
  final String? backgroundImagePath;
  final String? jobType;

  @override
  ConsumerState<_PollingView> createState() => _PollingViewState();
}

class _PollingViewState extends ConsumerState<_PollingView> {
  Timer? _fakeTimer;
  double _fakeProgress = 0.0;
  int _fakeTick = 0;
  bool _done = false;

  static const int _tickMs = 100;

  @override
  void initState() {
    super.initState();
    _startFakeProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(jobsProvider.notifier).pollJobStatus(
        widget.jobId,
        onUpdate: _handleUpdate,
      );
    });
  }

  void _startFakeProgress() {
    _fakeTimer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (timer) {
        if (!mounted) { timer.cancel(); return; }
        _fakeTick++;
        // Phase 1: 0→60% in 10s (100 ticks, +0.6/tick)
        // Phase 2: 60→90% in 10s (100 ticks, +0.3/tick)
        // Phase 3: 90→99% in 10s (100 ticks, +0.09/tick)
        double progress;
        if (_fakeTick <= 100) {
          progress = _fakeTick * 0.6;
        } else if (_fakeTick <= 200) {
          progress = 60.0 + (_fakeTick - 100) * 0.3;
        } else if (_fakeTick <= 300) {
          progress = 90.0 + (_fakeTick - 200) * 0.09;
        } else {
          timer.cancel();
          return;
        }
        setState(() => _fakeProgress = progress);
      },
    );
  }

  void _handleUpdate(JobModel job) {
    if (!mounted) return;
    if (job.isDone) {
      _fakeTimer?.cancel();
      ref.read(jobsProvider.notifier).stopPolling();
      setState(() => _done = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (job.isImageJob) {
          final urls = job.imageUrls.isNotEmpty
              ? job.imageUrls
              : (job.resultUrl != null ? [job.resultUrl!] : <String>[]);
          context.go('/work-image', extra: <String, dynamic>{'imageUrls': urls});
        } else if (job.resultUrl != null) {
          context.go('/result?resultUrl=${Uri.encodeComponent(job.resultUrl!)}');
        }
      });
    } else if (job.isFailed) {
      _fakeTimer?.cancel();
      ref.read(jobsProvider.notifier).stopPolling();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(job.error ?? 'Generation failed')),
        );
        context.go('/home');
      }
    }
  }

  @override
  void dispose() {
    _fakeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobsProvider);
    final job = state.jobs.where((j) => j.id == widget.jobId).firstOrNull;
    final realProgress = job?.progress ?? 0;
    final displayProgress = _done
        ? 100
        : max(_fakeProgress.toInt(), realProgress).clamp(0, 99);
    final isImageJob = job?.isImageJob ?? (widget.jobType == 'image');
    final isFailed = job?.isFailed ?? false;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _fakeTimer?.cancel();
          ref.read(jobsProvider.notifier).stopPolling();
          context.go('/home');
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ─────────────────────────────────────────────────
          widget.backgroundImagePath != null
              ? _BlurredBackground(imagePath: widget.backgroundImagePath!)
              : _GlowBackground(),

          // ── Foreground content ─────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _fakeTimer?.cancel();
                          ref.read(jobsProvider.notifier).stopPolling();
                          context.go('/home');
                        },
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
                    ],
                  ),
                ),
                const Spacer(),

                // ── Progress ring ─────────────────────────────────────
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Track
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: displayProgress / 100.0,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFF2A2A3E),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accentPurple,
                          ),
                        ),
                      ),
                      // Percent label
                      Text(
                        '$displayProgress%',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  isFailed
                      ? 'Generation failed'
                      : isImageJob
                          ? 'Generating your image...'
                          : 'Generating your video...',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isFailed
                      ? 'Please try again'
                      : job?.status == 'queued'
                          ? 'In queue...'
                          : 'AI is working on it',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: GestureDetector(
                    onTap: () {
                      _fakeTimer?.cancel();
                      ref.read(jobsProvider.notifier).stopPolling();
                      context.go('/history');
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'My Works',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blurred photo background
// ─────────────────────────────────────────────────────────────────────────────

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final isNetwork = imagePath.startsWith('http');
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: isNetwork
              ? CachedNetworkImage(
                  imageUrl: imagePath,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: AppColors.backgroundPrimary),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: AppColors.backgroundPrimary),
                )
              : Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppColors.backgroundPrimary),
                ),
        ),
        // Dark scrim so UI stays readable
        Container(color: Colors.black.withOpacity(0.62)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default purple glow background (video jobs)
// ─────────────────────────────────────────────────────────────────────────────

class _GlowBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentPurple.withOpacity(0.33),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentPurple.withOpacity(0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY VIEW (My Works tab)
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryView extends ConsumerStatefulWidget {
  const _HistoryView();

  @override
  ConsumerState<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<_HistoryView> {
  int _tab = 0;
  bool _loading = false;

  static const _tabs = ['My Works', 'Favorites', 'Recently'];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    try {
      await ref.read(jobsProvider.notifier).getUserJobs();
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) context.go('/home');
        },
      ),
      body: Stack(
        children: [
          _GlowBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(child: _buildContent(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: _tabs.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final isActive = _tab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accentPurpleLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.w400,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPurple),
      );
    }
    if (_tab == 0) {
      final jobs = ref.watch(jobsProvider).jobs;
      final doneJobs = jobs.where((j) => j.isDone).toList();
      if (doneJobs.isEmpty) return _buildEmptyState(context);
      return _buildJobsGrid(doneJobs);
    }
    return _buildEmptyState(context);
  }

  Widget _buildJobsGrid(List<JobModel> jobs) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 9 / 16,
      ),
      itemCount: jobs.length,
      itemBuilder: (_, i) {
        final job = jobs[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: AppColors.backgroundCard,
            child: job.resultUrl != null
                ? Image.network(
                    job.resultUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child:
                          Icon(Icons.videocam, color: AppColors.textHint),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.videocam, color: AppColors.textHint),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('☁️', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text(
              'No Works Yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "You haven't created anything yet. Start your first creation now!",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.go('/create'),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: AppColors.accentPurpleLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Create Now',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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

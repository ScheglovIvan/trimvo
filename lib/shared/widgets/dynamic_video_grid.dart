import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/shared/utils/video_utils.dart';
import 'package:trimvo/shared/widgets/scrolling_gif_grid.dart';
import 'package:video_player/video_player.dart';

class DynamicVideoGrid extends StatefulWidget {
  const DynamicVideoGrid({
    super.key,
    required this.controller,
    required this.videoUrls,
    this.speeds = const [0.3, 0.3, 0.3],
    this.offsets = const [0.0, -0.5, 0.0],
  });

  final AnimationController controller;
  final List<String> videoUrls;
  final List<double> speeds;
  final List<double> offsets;

  @override
  State<DynamicVideoGrid> createState() => _DynamicVideoGridState();
}

class _DynamicVideoGridState extends State<DynamicVideoGrid>
    with WidgetsBindingObserver {
  // Max 6 controllers (2 per column). Hardware video decoders are limited
  // (typically 4–8 slots on Android, fewer on older devices). 15 was causing
  // decoder exhaustion and crashes on mid-range phones.
  static const _kMaxControllers = 6;
  static const _kPerColumn = 2;

  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideos();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      for (final c in _controllers.values) {
        c.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      for (final c in _controllers.values) {
        c.play();
      }
    }
  }

  Future<void> _initVideos() async {
    final limit = _kMaxControllers.clamp(0, widget.videoUrls.length);
    for (int i = 0; i < limit; i++) {
      try {
        // Use cached controller so the second visit is instant.
        final ctrl = await initCachedVideoController(widget.videoUrls[i]);
        if (ctrl == null) continue;
        if (mounted) {
          setState(() => _controllers[i] = ctrl);
        } else {
          ctrl.pause();
          ctrl.dispose();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) {
      c.pause();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controllers.isEmpty) {
      return ScrollingGifGrid(
        controller: widget.controller,
        speeds: widget.speeds,
        offsets: widget.offsets,
      );
    }

    return ClipRect(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(3, (col) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: col == 1 ? 3 : 0),
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (_, __) {
                    final progress = col == 1
                        ? -(widget.controller.value * widget.speeds[col] +
                                  widget.offsets[col]) %
                              1.0
                        : (widget.controller.value * widget.speeds[col] +
                                widget.offsets[col]) %
                            1.0;
                    return FractionalTranslation(
                      translation: Offset(0, -progress),
                      child: _VideoColumn(
                        controllers: [
                          _controllers[col * _kPerColumn],
                          _controllers[col * _kPerColumn + 1],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _VideoColumn extends StatelessWidget {
  const _VideoColumn({required this.controllers});
  final List<VideoPlayerController?> controllers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemH = constraints.maxWidth * 16 / 9 + 6;
        // Repeat 4× so the column is tall enough to fill any screen without
        // gaps when FractionalTranslation scrolls it.
        final tiles = [
          ...controllers,
          ...controllers,
          ...controllers,
          ...controllers,
        ];
        return SizedBox(
          height: itemH * tiles.length,
          child: Column(
            children: tiles
                .map(
                  (ctrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: itemH - 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ctrl != null && ctrl.value.isInitialized
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: ctrl.value.size.width,
                                    height: ctrl.value.size.height,
                                    child: VideoPlayer(ctrl),
                                  ),
                                )
                              : const ColoredBox(color: AppColors.backgroundCard),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

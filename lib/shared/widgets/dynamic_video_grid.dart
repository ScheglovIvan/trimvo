import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';
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

class _DynamicVideoGridState extends State<DynamicVideoGrid> {
  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initVideos();
  }

  Future<void> _initVideos() async {
    for (int i = 0; i < widget.videoUrls.length && i < 15; i++) {
      try {
        final ctrl = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrls[i]),
        );
        await ctrl.initialize();
        await ctrl.setLooping(true);
        await ctrl.setVolume(0);
        await ctrl.play();
        if (mounted) {
          setState(() => _controllers[i] = ctrl);
        } else {
          ctrl.dispose();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
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
                          _controllers[col * 5],
                          _controllers[col * 5 + 1],
                          _controllers[col * 5 + 2],
                          _controllers[col * 5 + 3],
                          _controllers[col * 5 + 4],
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
                )
                .toList(),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';

class ScrollingGifGrid extends StatelessWidget {
  const ScrollingGifGrid({
    super.key,
    required this.controller,
    this.speeds = const [0.3, 0.3, 0.3],
    this.offsets = const [0.0, -0.5, 0.0],
  });

  final AnimationController controller;
  final List<double> speeds;
  final List<double> offsets;

  static const List<String> _gifPaths = [
    'assets/images/templates/g01.gif',
    'assets/images/templates/g02.gif',
    'assets/images/templates/g03.gif',
    'assets/images/templates/g04.gif',
    'assets/images/templates/g05.gif',
    'assets/images/templates/g06.gif',
    'assets/images/templates/g07.gif',
    'assets/images/templates/g08.gif',
    'assets/images/templates/g09.gif',
    'assets/images/templates/g010.gif',
    'assets/images/templates/g011.gif',
    'assets/images/templates/g012.gif',
    'assets/images/templates/g013.gif',
    'assets/images/templates/g014.gif',
    'assets/images/templates/g015.gif',
  ];

  @override
  Widget build(BuildContext context) {
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
                  animation: controller,
                  builder: (_, __) {
                    final progress = col == 1
                        ? -(controller.value * speeds[col] + offsets[col]) % 1.0
                        : (controller.value * speeds[col] + offsets[col]) % 1.0;
                    return FractionalTranslation(
                      translation: Offset(0, -progress),
                      child: _GifColumn(
                        paths: [
                          _gifPaths[col * 5],
                          _gifPaths[col * 5 + 1],
                          _gifPaths[col * 5 + 2],
                          _gifPaths[col * 5 + 3],
                          _gifPaths[col * 5 + 4],
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

class _GifColumn extends StatelessWidget {
  const _GifColumn({required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemHeight = constraints.maxWidth * 16 / 9 + 6;
        final tiles = [...paths, ...paths, ...paths, ...paths];
        return SizedBox(
          height: itemHeight * tiles.length,
          child: Column(
            children: tiles.map((path) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: constraints.maxWidth,
                height: itemHeight - 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    path,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: AppColors.backgroundCard),
                  ),
                ),
              ),
            )).toList(),
          ),
        );
      },
    );
  }
}

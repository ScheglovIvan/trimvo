import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';

Future<String?> showFaceDetectScreen(
  BuildContext context, {
  required String imagePath,
}) async {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FaceDetectScreen(imagePath: imagePath),
    ),
  );
}

class FaceDetectScreen extends StatefulWidget {
  const FaceDetectScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<FaceDetectScreen> createState() => _FaceDetectScreenState();
}

class _FaceDetectScreenState extends State<FaceDetectScreen> {
  bool _faceSelected = true;

  Rect _simulateFaceRect(Size widgetSize) {
    final faceSize = widgetSize.width * 0.25;
    return Rect.fromCenter(
      center: Offset(widgetSize.width / 2, widgetSize.height * 0.28),
      width: faceSize,
      height: faceSize * 1.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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
                  Expanded(
                    child: Text(
                      'Select Characters',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap faces to select (Max 2)',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Image with face rect overlay
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      final faceRect = _simulateFaceRect(size);
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _faceSelected = !_faceSelected),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: AppColors.backgroundCard,
                              ),
                            ),
                            CustomPaint(
                              painter: _FaceRectPainter(
                                rect: faceRect,
                                selected: _faceSelected,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Face thumbnails row
            if (_faceSelected) ...[
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FaceThumbnail(
                      imagePath: widget.imagePath,
                      selected: _faceSelected,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Buttons
            Padding(
              padding:
                  EdgeInsets.fromLTRB(16, 0, 16, bottomPad > 0 ? bottomPad : 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Retake',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _faceSelected
                          ? () => Navigator.of(context).pop(widget.imagePath)
                          : null,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: _faceSelected
                              ? AppColors.accentPurpleLight
                              : AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _faceSelected ? 'Confirm (1)' : 'Confirm',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _faceSelected
                                ? AppColors.textPrimary
                                : AppColors.textHint,
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

class _FaceThumbnail extends StatelessWidget {
  const _FaceThumbnail({required this.imagePath, required this.selected});

  final String imagePath;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.accentPurple : AppColors.textHint,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: AppColors.backgroundCard),
        ),
      ),
    );
  }
}

class _FaceRectPainter extends CustomPainter {
  const _FaceRectPainter({required this.rect, required this.selected});

  final Rect rect;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (!selected) return;

    final paint = Paint()
      ..color = AppColors.accentPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(rect, paint);

    // Corner decorations
    const cornerLen = 12.0;
    final corners = [
      [rect.topLeft, Offset(rect.left + cornerLen, rect.top),
       Offset(rect.left, rect.top + cornerLen)],
      [rect.topRight, Offset(rect.right - cornerLen, rect.top),
       Offset(rect.right, rect.top + cornerLen)],
      [rect.bottomLeft, Offset(rect.left + cornerLen, rect.bottom),
       Offset(rect.left, rect.bottom - cornerLen)],
      [rect.bottomRight, Offset(rect.right - cornerLen, rect.bottom),
       Offset(rect.right, rect.bottom - cornerLen)],
    ];

    final cornerPaint = Paint()
      ..color = AppColors.accentPurpleLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final c in corners) {
      canvas.drawLine(c[0], c[1], cornerPaint);
      canvas.drawLine(c[0], c[2], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceRectPainter old) =>
      old.rect != rect || old.selected != selected;
}

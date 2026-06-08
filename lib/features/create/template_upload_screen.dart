import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/widgets/app_background.dart';
import 'package:trimvo/features/auth/login_bottom_sheet.dart';
import 'package:trimvo/features/create/face_detect_screen.dart';
import 'package:trimvo/features/create/photo_picker_sheet.dart';
import 'package:trimvo/models/template_model.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:trimvo/providers/jobs_provider.dart';
import 'package:trimvo/providers/pricing_provider.dart';
import 'package:trimvo/providers/templates_provider.dart';
import 'package:trimvo/services/api_service.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';

class TemplateUploadScreen extends ConsumerStatefulWidget {
  const TemplateUploadScreen({super.key, required this.templateId});

  final String templateId;

  @override
  ConsumerState<TemplateUploadScreen> createState() =>
      _TemplateUploadScreenState();
}

class _TemplateUploadScreenState extends ConsumerState<TemplateUploadScreen> {
  String? _photo1;
  String? _photo2;
  bool _isGenerating = false;

  Future<void> _pickPhoto({
    required String gender,
    required bool isSlot2,
  }) async {
    final path = await showPhotoPickerSheet(context, gender: gender);
    if (path == null || !mounted) return;

    String? confirmedPath = path;
    if (!path.startsWith('http')) {
      confirmedPath = await showFaceDetectScreen(context, imagePath: path);
      if (confirmedPath == null || !mounted) return;
    }

    setState(() {
      if (isSlot2) {
        _photo2 = confirmedPath;
      } else {
        _photo1 = confirmedPath;
      }
    });
  }

  Future<void> _onGenerate(
    BuildContext context,
    TemplateModel template,
    PricingModel pricing,
  ) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      final loggedIn = await showLoginBottomSheet(context);
      if (!loggedIn || !context.mounted) return;
    }

    if (ApiService.token == null) {
      await ref.read(authProvider.notifier).loadFromStorage();
      if (ApiService.token == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in again')),
        );
        return;
      }
    }

    if (!context.mounted) return;
    if (!_hasRequiredPhotos(template)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            template.photoSlots >= 2
                ? 'Please upload both photos.'
                : 'Please upload a photo.',
          ),
          backgroundColor: AppColors.accentPurple,
        ),
      );
      return;
    }

    final currentAuth = ref.read(authProvider);
    final cost = pricing.calculate(
      templateBaseCost: template.gemsCost,
      duration: '5s',
      quality: 'standard',
      isSvip: currentAuth.isSvip,
    );
    if (currentAuth.gems < cost) {
      if (!context.mounted) return;
      if (!currentAuth.isSvip) {
        context.push('/home/paywall?svip=true');
      } else {
        context.push('/home/gems');
      }
      return;
    }

    setState(() => _isGenerating = true);
    try {
      String? photoUrl1 = _photo1;
      String? photoUrl2 = _photo2;

      if (_photo1 != null && !_photo1!.startsWith('http')) {
        photoUrl1 = await ApiService.uploadPhoto(_photo1!);
      }
      if (_photo2 != null && !_photo2!.startsWith('http')) {
        photoUrl2 = await ApiService.uploadPhoto(_photo2!);
      }

      final options = <String, dynamic>{
        'duration': '5s',
        'quality': 'standard',
        if (template.photoSlots >= 2) ...{
          'photo_url_male': photoUrl1,
          'photo_url_female': photoUrl2,
        } else if (template.photoSlots == 1)
          'photo_url': photoUrl1,
      };

      // Use widget.templateId (from URL params) — template.id may be empty
      // if the detail endpoint omits the id field in its response.
      final jobId =
          await ref.read(jobsProvider.notifier).createJob(widget.templateId, options);
      await ref.read(authProvider.notifier).refreshBalance();

      if (context.mounted) {
        context.go(
          '/generating?jobId=${Uri.encodeComponent(jobId)}',
          extra: <String, dynamic>{
            'imagePath': template.thumbUrl,
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  bool _hasRequiredPhotos(TemplateModel template) {
    if (template.photoSlots >= 2) return _photo1 != null && _photo2 != null;
    return _photo1 != null;
  }

  bool _canGenerate(TemplateModel template) =>
      !_isGenerating && _hasRequiredPhotos(template);

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(templateDetailProvider(widget.templateId));
    final pricingAsync = ref.watch(pricingProvider);
    final isSvip = ref.watch(authProvider).isSvip;

    return PopScope(
      canPop: true,
      child: AppBackground(
        child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: templateAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error loading template',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
            data: (template) => Column(
              children: [
                const _TopBar(title: 'Upload Photo'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                    child: _buildBody(template),
                  ),
                ),
                _buildBottomSection(context, template, pricingAsync, isSvip),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBody(TemplateModel template) {
    if (template.photoSlots >= 2) {
      return _buildTwoSlots(template);
    }
    return _buildOneSlot(template);
  }

  Widget _buildOneSlot(TemplateModel template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Upload Photo',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload a clear photo',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 180,
            child: _PhotoSlot(
              photoPath: _photo1,
              gender: 'any',
              onTap: () => _pickPhoto(gender: 'any', isSlot2: false),
              onClear: () => setState(() => _photo1 = null),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoSlots(TemplateModel template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Upload 2 Photos',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload a clear photo',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        const Row(
          children: [
            _GenderPill(label: 'Male', isMale: true),
            SizedBox(width: 8),
            _GenderPill(label: 'Female', isMale: false),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _PhotoSlot(
                photoPath: _photo1,
                gender: 'male',
                onTap: () => _pickPhoto(gender: 'male', isSlot2: false),
                onClear: () => setState(() => _photo1 = null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoSlot(
                photoPath: _photo2,
                gender: 'female',
                onTap: () => _pickPhoto(gender: 'female', isSlot2: true),
                onClear: () => setState(() => _photo2 = null),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    TemplateModel template,
    AsyncValue<PricingModel> pricingAsync,
    bool isSvip,
  ) {
    final pricing = pricingAsync.valueOrNull ?? const PricingModel();
    final cost = pricing.calculate(
      templateBaseCost: template.gemsCost,
      duration: '5s',
      quality: 'standard',
      isSvip: isSvip,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => context.push('/paywall?svip=true'),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Want to save gems? ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: 'Get SVIP (50% OFF).',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.svipGold,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.svipGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _canGenerate(template)
                ? () => _onGenerate(context, template, pricing)
                : null,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: _canGenerate(template)
                    ? const LinearGradient(
                        colors: [Color(0xFF8B47F5), Color(0xFF6B2FD5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _canGenerate(template)
                    ? null
                    : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: _isGenerating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.textPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Generate Video',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _canGenerate(template)
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.diamond,
                              color: _canGenerate(template)
                                  ? AppColors.svipGold
                                  : AppColors.textHint,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$cost',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _canGenerate(template)
                                    ? AppColors.svipGold
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.textHint,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                'Failed task? 100% refund.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
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
              title,
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
    );
  }
}

class _GenderPill extends StatelessWidget {
  const _GenderPill({required this.label, required this.isMale});

  final String label;
  final bool isMale;

  @override
  Widget build(BuildContext context) {
    final iconColor = isMale ? const Color(0xFF4FC3F7) : const Color(0xFFF48FB1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMale ? Icons.male : Icons.female,
              color: iconColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.photoPath,
    required this.gender,
    required this.onTap,
    required this.onClear,
  });

  final String? photoPath;
  final String gender;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 9 / 14,
        child: photoPath != null
            ? _buildFilledSlot(photoPath!)
            : _buildEmptySlot(),
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const CustomPaint(
        painter: _DashedBorderPainter(color: Color(0xFF3A3A50)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(64, 64),
                  painter: _CornerFramePainter(
                    color: Color(0xFF4FC3F7),
                  ),
                ),
                Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFFE091FF),
                  size: 30,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilledSlot(String path) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.backgroundCard),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: path.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: path,
                  cacheManager: AppCacheManager(),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: 480,
                  memCacheHeight: 480,
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: AppColors.backgroundCard),
                )
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppColors.backgroundCard),
                ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: AppColors.textPrimary, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  const _CornerFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 14.0;
    const r = 6.0;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, len), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height), Offset(len, size.height), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - len), Offset(size.width, size.height - r), paint);
    canvas.drawLine(Offset(size.width - len, size.height), Offset(size.width - r, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerFramePainter old) => old.color != color;
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = 16.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final start = metric.getTangentForOffset(distance);
        final end = metric.getTangentForOffset(
          (distance + dashWidth).clamp(0.0, metric.length),
        );
        if (start != null && end != null) {
          canvas.drawLine(start.position, end.position, paint);
        }
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}

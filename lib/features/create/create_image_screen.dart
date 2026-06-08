import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/widgets/app_background.dart';
import 'package:trimvo/features/auth/login_bottom_sheet.dart';
import 'package:trimvo/features/create/photo_picker_sheet.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:trimvo/providers/jobs_provider.dart';
import 'package:trimvo/providers/pricing_provider.dart';
import 'package:trimvo/shared/widgets/app_cache_manager.dart';
import 'package:trimvo/shared/widgets/hint_video_sheet.dart';

class CreateImageScreen extends ConsumerStatefulWidget {
  const CreateImageScreen({super.key});

  @override
  ConsumerState<CreateImageScreen> createState() => _CreateImageScreenState();
}

class _CreateImageScreenState extends ConsumerState<CreateImageScreen> {
  String? _imagePath;
  String _aspectRatio = '1:1';
  int _numImages = 1;
  bool _promptEnhance = true;
  bool _isGenerating = false;
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final path = await showPhotoPickerSheet(context, gender: 'female');
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  Future<void> _onGenerate() async {
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a reference image')),
      );
      return;
    }
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      final loggedIn = await showLoginBottomSheet(context);
      if (!loggedIn || !mounted) return;
    }

    final pricing = ref.read(pricingProvider).valueOrNull ?? const PricingModel();
    final cost = pricing.imageGenerationCost(isSvip: ref.read(authProvider).isSvip) * _numImages;
    final currentAuth = ref.read(authProvider);
    if (currentAuth.gems < cost) {
      if (!mounted) return;
      if (!currentAuth.isSvip) {
        context.push('/home/paywall?svip=true');
      } else {
        context.push('/home/gems');
      }
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final jobId = await ref.read(jobsProvider.notifier).createImageJob(
            photoPath: _imagePath!,
            prompt: _promptController.text,
            aspectRatio: _aspectRatio,
            numOutputs: _numImages,
          );
      if (mounted) {
        context.push(
          '/home/generating?jobId=$jobId',
          extra: <String, dynamic>{
            'imagePath': _imagePath,
            'jobType': 'image',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSvip = ref.watch(authProvider).isSvip;
    final pricing = ref.watch(pricingProvider).valueOrNull ?? const PricingModel();
    final cost = pricing.imageGenerationCost(isSvip: isSvip) * _numImages;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _buildBody(),
                ),
              ),
              _buildBottomSection(context, cost),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.backgroundCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
          Expanded(
            child: Text(
              'Create Image',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => showHintVideoSheet(
              context,
              'assets/videos/img2img.mp4',
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.backgroundCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_outline,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageSlot(),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Let AI fill the space between your frames.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildPromptSection(),
        const SizedBox(height: 20),
        _buildAspectRatioSection(),
        const SizedBox(height: 20),
        _buildNumImagesSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildImageSlot() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: AspectRatio(
            aspectRatio: 1,
            child: _imagePath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: AppColors.backgroundCard),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _imagePath!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: _imagePath!,
                                cacheManager: AppCacheManager(),
                                fit: BoxFit.cover,
                                memCacheWidth: 480,
                                memCacheHeight: 480,
                                errorWidget: (_, __, ___) =>
                                    const ColoredBox(color: AppColors.backgroundCard),
                              )
                            : Image.file(
                                File(_imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: AppColors.backgroundCard),
                              ),
                      ),
                    ],
                  )
                : CustomPaint(
                    painter: const _DashedBorderPainter(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add,
                              color: AppColors.accentPurple, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Add Image',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Prompt',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  'Prompt Enhance',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _promptEnhance = !_promptEnhance),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _promptEnhance
                          ? AppColors.accentPurpleLight
                          : AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: _promptEnhance
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _promptController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style:
                GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Describe the scene, action, and style...',
              hintStyle: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textHint),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAspectRatioSection() {
    const options = ['1:1', '3:4', '4:3', '16:9'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aspect Ratio',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(options.length, (i) {
            final ratio = options[i];
            final isActive = _aspectRatio == ratio;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _aspectRatio = ratio),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 64,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accentPurpleLight
                          : AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AspectRatioIcon(ratio: ratio, isActive: isActive),
                        const SizedBox(height: 5),
                        Text(
                          ratio,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNumImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Number of Images',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              _buildStepBtn(Icons.remove,
                  () { if (_numImages > 1) setState(() => _numImages--); }),
              Expanded(
                child: Text(
                  '$_numImages ${_numImages == 1 ? 'Image' : 'Images'}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildStepBtn(Icons.add,
                  () { if (_numImages < 4) setState(() => _numImages++); }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context, int cost) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
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
                        fontSize: 13, color: AppColors.textSecondary),
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
          const SizedBox(height: 10),
          Opacity(
            opacity: (_imagePath == null || _isGenerating) ? 0.4 : 1.0,
            child: GestureDetector(
            onTap: (_imagePath == null || _isGenerating) ? null : _onGenerate,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B47F5), Color(0xFF6B2FD5)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: _isGenerating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Generate Image',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.diamond_outlined,
                                color: AppColors.gemBlue, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$cost',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.svipGold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: AppColors.textHint, size: 14),
              const SizedBox(width: 4),
              Text(
                'Failed task? 100% refund.',
                style:
                    GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AspectRatioIcon extends StatelessWidget {
  const _AspectRatioIcon({required this.ratio, required this.isActive});

  final String ratio;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    double w, h;
    switch (ratio) {
      case '3:4':
        w = 14;
        h = 19;
      case '4:3':
        w = 19;
        h = 14;
      case '16:9':
        w = 24;
        h = 13;
      default: // 1:1
        w = 17;
        h = 17;
    }
    final color = isActive ? AppColors.textPrimary : AppColors.textSecondary;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textSecondary
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
  bool shouldRepaint(covariant CustomPainter old) => false;
}

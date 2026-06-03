import 'dart:io';
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
import 'package:trimvo/shared/widgets/hint_video_sheet.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key, this.templateId});

  final String? templateId;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  int _tab = 0;
  String _duration = '5s';
  String _quality = 'Standard';
  String _orientation = 'Portrait';
  bool _promptEnhance = true;
  bool _isGenerating = false;
  String? _refImage1;
  String? _refImage2;
  String? _startImage;
  String? _endImage;
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(String) onPicked) async {
    final path = await showPhotoPickerSheet(context, gender: 'female');
    if (path != null && mounted) setState(() => onPicked(path));
  }

  // Backend cost defaults: standard=300, high=600, premium=1200
  static const _costs = {'Standard': 300, 'High': 600, 'Ultra HD': 1200};

  String get _apiQuality => switch (_quality) {
        'High' => 'high',
        'Ultra HD' => 'premium',
        _ => 'standard',
      };

  String get _apiResolution =>
      _orientation == 'Landscape' ? '1920x1080' : '1080x1920';

  String? get _primaryPhoto => _tab == 0 ? _refImage1 : _startImage;
  String? get _secondaryPhoto => _tab == 0 ? _refImage2 : _endImage;

  Future<void> _onGenerate() async {
    final photo1 = _primaryPhoto;
    if (photo1 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      final loggedIn = await showLoginBottomSheet(context);
      if (!loggedIn || !mounted) return;
    }
    setState(() => _isGenerating = true);
    try {
      final promptText = _promptController.text.trim().isEmpty
          ? 'Create a cinematic video'
          : _promptController.text.trim();

      final jobId = await ref.read(jobsProvider.notifier).createCustomJob(
            photo1Path: photo1,
            photo2Path: _secondaryPhoto,
            prompt: promptText,
            resolution: _apiResolution,
            quality: _apiQuality,
            format: 'mp4',
          );
      if (mounted) context.go('/generating?jobId=$jobId');
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
    final baseCost = _costs[_quality] ?? 300;
    final cost = isSvip ? (baseCost / 2).ceil() : baseCost;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: 'Create Video',
                onHint: () => showHintVideoSheet(
                  context,
                  'assets/videos/img2video.mp4',
                ),
              ),
              const SizedBox(height: 12),
              _buildTabBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child:
                      _tab == 0 ? _buildReferenceTab() : _buildStartEndTab(),
                ),
              ),
              _buildBottomSection(context, cost),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _buildTabItem(0, 'Reference'),
            _buildTabItem(1, 'Start & End'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isActive = _tab == index;
    final isReference = index == 0;
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => setState(() => _tab = index),
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
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (isReference)
            Positioned(
              top: -10,
              right: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF89EFF), Color(0xFFA2D2FD)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Audio',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferenceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageSlotsRow(
          image1: _refImage1,
          image2: _refImage2,
          label1: 'Add Image',
          label2: 'Add Image',
          onTap1: () => _pickImage((p) => _refImage1 = p),
          onTap2: () => _pickImage((p) => _refImage2 = p),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Source Image (1-2)',
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
        _buildDurationSection(),
        const SizedBox(height: 20),
        _buildQualitySection(),
        const SizedBox(height: 20),
        _buildOrientationSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStartEndTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageSlotsRow(
          image1: _startImage,
          image2: _endImage,
          label1: 'Add Start Frame',
          label2: 'Add End Frame',
          tag1: 'Start',
          tag2: 'End',
          onTap1: () => _pickImage((p) => _startImage = p),
          onTap2: () => _pickImage((p) => _endImage = p),
          primaryActive: true,
        ),
        const SizedBox(height: 12),
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
        _buildDurationSection(),
        const SizedBox(height: 20),
        _buildQualitySection(),
        const SizedBox(height: 20),
        _buildOrientationSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildImageSlotsRow({
    required String? image1,
    required String? image2,
    required String label1,
    required String label2,
    required VoidCallback onTap1,
    required VoidCallback onTap2,
    String? tag1,
    String? tag2,
    bool primaryActive = false,
  }) {
    final secondEnabled = image1 != null;
    return Row(
      children: [
        Expanded(
          child: _ImageSlot(
            imagePath: image1,
            label: label1,
            tag: tag1,
            isActive: true,
            enabled: true,
            onTap: onTap1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ImageSlot(
            imagePath: image2,
            label: label2,
            tag: tag2,
            isActive: false,
            enabled: secondEnabled,
            onTap: onTap2,
          ),
        ),
      ],
    );
  }

  Widget _buildPromptSection() {
    return _PromptSection(
      controller: _promptController,
      enhance: _promptEnhance,
      onEnhanceToggle: () =>
          setState(() => _promptEnhance = !_promptEnhance),
    );
  }

  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChoiceButton(
                label: '5s',
                isActive: _duration == '5s',
                onTap: () => setState(() => _duration = '5s'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChoiceButton(
                label: '10s',
                isActive: _duration == '10s',
                onTap: () => setState(() => _duration = '10s'),
                svipBadge: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQualitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quality',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChoiceButton(
                label: 'Standard',
                isActive: _quality == 'Standard',
                onTap: () => setState(() => _quality = 'Standard'),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceButton(
                label: 'High',
                isActive: _quality == 'High',
                onTap: () => setState(() => _quality = 'High'),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceButton(
                label: 'Ultra HD',
                isActive: _quality == 'Ultra HD',
                onTap: () => setState(() => _quality = 'Ultra HD'),
                svipBadge: true,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrientationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orientation',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OrientationButton(
                label: 'Portrait',
                icon: Icons.crop_portrait,
                isActive: _orientation == 'Portrait',
                onTap: () => setState(() => _orientation = 'Portrait'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OrientationButton(
                label: 'Landscape',
                icon: Icons.crop_landscape,
                isActive: _orientation == 'Landscape',
                onTap: () => setState(() => _orientation = 'Landscape'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSection(BuildContext context, int cost) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => context.go('/paywall?svip=true'),
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
          const SizedBox(height: 10),
          Opacity(
            opacity: (_primaryPhoto == null || _isGenerating) ? 0.4 : 1.0,
            child: GestureDetector(
              onTap: (_primaryPhoto == null || _isGenerating) ? null : _onGenerate,
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
                            'Generate Video',
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
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.onHint});

  final String title;
  final VoidCallback? onHint;

  @override
  Widget build(BuildContext context) {
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
          if (onHint != null)
            GestureDetector(
              onTap: onHint,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMAGE SLOT
// ═══════════════════════════════════════════════════════════════════════════════

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.label,
    required this.isActive,
    required this.enabled,
    required this.onTap,
    this.imagePath,
    this.tag,
  });

  final String label;
  final bool isActive;
  final bool enabled;
  final VoidCallback onTap;
  final String? imagePath;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isActive ? AppColors.accentPurple : AppColors.textHint;
    final textColor =
        isActive ? AppColors.textPrimary : AppColors.textHint;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imagePath!.startsWith('http')
                    ? Image.network(
                        imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: AppColors.backgroundCard),
                      )
                    : Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: AppColors.backgroundCard),
                      ),
              )
            else
              CustomPaint(
                painter: _DashedBorderPainter(
                  color: isActive ? AppColors.textSecondary : AppColors.textHint,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tag != null) const SizedBox(height: 28),
                      Icon(Icons.add, color: iconColor, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (tag != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
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

// ═══════════════════════════════════════════════════════════════════════════════
// PROMPT SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _PromptSection extends StatelessWidget {
  const _PromptSection({
    required this.controller,
    required this.enhance,
    required this.onEnhanceToggle,
  });

  final TextEditingController controller;
  final bool enhance;
  final VoidCallback onEnhanceToggle;

  @override
  Widget build(BuildContext context) {
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
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _ToggleSwitch(value: enhance, onToggle: onEnhanceToggle),
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
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Describe the scene, action, and style...',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textHint,
              ),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.value, required this.onToggle});

  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          color: value
              ? AppColors.accentPurpleLight
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHOICE BUTTON (Duration / Quality) — SVIP badge floats above
// ═══════════════════════════════════════════════════════════════════════════════

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.svipBadge = false,
    this.fontSize = 14,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool svipBadge;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accentPurpleLight
                  : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(30),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        if (svipBadge)
          Positioned(
            top: -10,
            right: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'SVIP',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORIENTATION BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _OrientationButton extends StatelessWidget {
  const _OrientationButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentPurpleLight
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

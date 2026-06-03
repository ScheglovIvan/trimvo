import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/theme/app_text_styles.dart';
import 'package:trimvo/shared/widgets/custom_button.dart';
import 'package:trimvo/shared/widgets/local_background_video.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: [
          _AwakenPage(onNext: _goToNextPage),
          _StylesPage(
            currentPage: _currentPage,
            onNext: _goToNextPage,
          ),
          _BringToLifePage(
            currentPage: _currentPage,
            onContinue: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 1 — Awaken Your Photos
// ═══════════════════════════════════════════════════════════════════════════════

class _AwakenPage extends StatelessWidget {
  const _AwakenPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ClipRect(
        child: Stack(
      fit: StackFit.expand,
      children: [
        const LocalBackgroundVideo(),

        // Bottom fade: transparent at 40% → fully #0D0D0D at bottom
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.4, 1.0],
              colors: [Colors.transparent, AppColors.backgroundPrimary],
            ),
          ),
        ),

        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Awaken', style: AppTextStyles.heroTitle),
                  Text('Your Photos.', style: AppTextStyles.heroSubtitle),
                  const SizedBox(height: 12),
                  Text(
                    'Turn static memories into cinematic videos. No skills required.',
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(label: 'Start Creating', trailingIcon: true, onPressed: onNext),
                  const SizedBox(height: 12),
                  const _TermsText(),
                ],
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

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 2 — 1000+ Styles
// ═══════════════════════════════════════════════════════════════════════════════

class _StylesPage extends StatelessWidget {
  const _StylesPage({
    required this.currentPage,
    required this.onNext,
  });

  final int currentPage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: dark + radial purple glow at top
        const DecoratedBox(
          decoration: BoxDecoration(color: AppColors.backgroundPrimary),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0x667B3FE4), Colors.transparent],
              center: Alignment.topCenter,
              radius: 1.1,
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Column(
            children: [
              // ── Image placeholder (top ~60%) ──────────────────────────────
              Expanded(
                flex: 60,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Container(
                      width: screenWidth - 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1A3E),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPurple.withOpacity(0.5),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/templates/onb01.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: AppColors.backgroundCard),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Bottom content (bottom ~40%) ──────────────────────────────
              Expanded(
                flex: 40,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '1000+ Styles',
                        style: AppTextStyles.sectionTitle
                            .copyWith(fontSize: 32),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'From Cyberpunk to Wedding. Just one tap.',
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _DotsIndicator(
                        count: 3,
                        activeIndex: currentPage,
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        label: 'Continue',
                        onPressed: onNext,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOTS INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return Padding(
          padding: EdgeInsets.only(right: i < count - 1 ? 6 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.bottomNavActive
                  : AppColors.bottomNavInactive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERMS TEXT
// ═══════════════════════════════════════════════════════════════════════════════

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    const grey = TextStyle(color: AppColors.textSecondary, fontSize: 12);
    const white = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 12,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textPrimary,
    );

    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: grey,
            children: [
              TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(text: 'Terms', style: white),
              TextSpan(text: ' & '),
              TextSpan(text: 'Privacy', style: white),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'AI-generated content may vary.',
          style: grey,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 3 — Bring Photos to Life
// ═══════════════════════════════════════════════════════════════════════════════

class _BringToLifePage extends StatefulWidget {
  const _BringToLifePage({
    required this.currentPage,
    required this.onContinue,
  });

  final int currentPage;
  final VoidCallback onContinue;

  @override
  State<_BringToLifePage> createState() => _BringToLifePageState();
}

class _BringToLifePageState extends State<_BringToLifePage> {
  late final PageController _carouselController;
  double _page = 0.0;

  static const int _initialCard = 1;
  static const List<String> _carouselImages = [
    'assets/images/templates/onb02.jpg',
    'assets/images/templates/onb03.jpg',
    'assets/images/templates/onb04.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(
      viewportFraction: 0.75,
      initialPage: _initialCard,
    );
    _page = _carouselController.initialPage.toDouble();
    _carouselController.addListener(() {
      if (mounted) {
        setState(() => _page = _carouselController.page ?? _page);
      }
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: dark + radial purple glow at top
        const DecoratedBox(
          decoration: BoxDecoration(color: AppColors.backgroundPrimary),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0x667B3FE4), Colors.transparent],
              center: Alignment.topCenter,
              radius: 1.1,
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              // ── Inner card carousel (top ~58%) ───────────────────────────
              Expanded(
                flex: 58,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: PageView.builder(
                    controller: _carouselController,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      final scale = (1.0 - (_page - index).abs() * 0.15)
                          .clamp(0.85, 1.0);
                      return Transform.scale(
                        scale: scale,
                        child: _CarouselCard(
                          isCenter: index == _initialCard,
                          imagePath: _carouselImages[index],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Bottom content (bottom ~42%) ──────────────────────────────
              Expanded(
                flex: 42,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bring Photos to Life',
                        style: AppTextStyles.sectionTitle.copyWith(fontSize: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Animate portraits, pets, and memories.',
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: _DotsIndicator(
                          count: 3,
                          activeIndex: widget.currentPage,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        label: 'Continue',
                        onPressed: widget.onContinue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Carousel card ────────────────────────────────────────────────────────────

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.isCenter, required this.imagePath});

  final bool isCenter;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A1A3E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isCenter
              ? [
                  BoxShadow(
                    color: AppColors.accentPurple.withOpacity(0.45),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.backgroundCard),
            ),
            if (isCenter) ...[
              // Small static photo thumbnail — bottom-left overlay
              Positioned(
                bottom: 20,
                left: 16,
                child: Container(
                  width: 90,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
              // Curved arrow from small card upward
              const Positioned(
                bottom: 130,
                left: 88,
                child: _CurvedArrow(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Curved arrow ─────────────────────────────────────────────────────────────

class _CurvedArrow extends StatelessWidget {
  const _CurvedArrow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(44, 52),
      painter: _CurvedArrowPainter(),
    );
  }
}

class _CurvedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPurple
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Bezier curve: starts bottom-left, ends top-right
    final path = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        0, size.height * 0.4,
        size.width * 0.7, size.height * 0.2,
        size.width, 0,
      );
    canvas.drawPath(path, paint);

    // Arrowhead at end point (size.width, 0)
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - 10, 7),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - 5, -9),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

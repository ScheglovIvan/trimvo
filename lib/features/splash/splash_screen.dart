import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:trimvo/providers/preload_provider.dart';

const _onboardingSeenKey = 'onboarding_seen';

class _GradientArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.12;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF2A1A3E);
    canvas.drawCircle(center, radius, trackPaint);

    const sweepAngle = 4.71239;
    final shader = const SweepGradient(
      colors: [
        Colors.transparent,
        Color(0xFF7B3FE4),
        Color(0xFFB47FFF),
      ],
      stops: [0.0, 0.6, 1.0],
      startAngle: 0,
      endAngle: 4.71239,
    ).createShader(rect);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _spinCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_onboardingSeenKey) ?? false;

    if (!seen) {
      // First launch: start pre-caching in background, go to onboarding immediately.
      unawaited(ref.read(preloadProvider.notifier).start());
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) context.go('/onboarding');
      return;
    }

    // Subsequent launches: wait until all resources are cached.
    await Future.wait([
      ref.read(preloadProvider.notifier).start(),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);

    if (!mounted) return;

    final auth = ref.read(authProvider);
    if (auth.isLoggedIn && !auth.isSvip) {
      context.go('/paywall?svip=true');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preload = ref.watch(preloadProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2A0A4A),
                  Color(0xFF160528),
                  Color(0xFF0D0D0D),
                  Color(0xFF0D0D0D),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),

          Positioned(
            top: -80,
            left: -40,
            right: -40,
            child: Container(
              height: 380,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentPurple.withOpacity(0.45),
                    Colors.transparent,
                  ],
                  center: Alignment.center,
                  radius: 0.7,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                AnimatedBuilder(
                  animation: _textOpacity,
                  builder: (_, child) => Opacity(
                    opacity: _textOpacity.value,
                    child: child,
                  ),
                  child: RotationTransition(
                    turns: _spinCtrl,
                    child: CustomPaint(
                      size: const Size(36, 36),
                      painter: _GradientArcPainter(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Progress bar — visible only while caching (total > 0)
                AnimatedOpacity(
                  opacity: preload.total > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: preload.progress,
                            minHeight: 3,
                            backgroundColor: const Color(0xFF2A1A3E),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B47F5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${preload.done} / ${preload.total}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                AnimatedBuilder(
                  animation: _textOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Trimvo',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 20,
                            color: AppColors.textPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/providers/iap_provider.dart';
import 'package:trimvo/providers/subscription_plans_provider.dart';
import 'package:trimvo/shared/widgets/local_background_video.dart';

const _vipGradient = LinearGradient(
  colors: [Color(0xFFBC5EF3), Color(0xFF6834ED)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const _svipGradient = LinearGradient(
  colors: [Color(0xFFFFAB9D), Color(0xFFFEFA19)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const _vipBadgeGradient = LinearGradient(
  colors: [Color(0xFFF89EFF), Color(0xFFA2D2FD)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

enum _Plan { yearly, weekly }

enum _Tier { vip, svip }

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.initialSvip = false});

  final bool initialSvip;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Plan _plan = _Plan.weekly;
  late _Tier _tier;

  @override
  void initState() {
    super.initState();
    _tier = widget.initialSvip ? _Tier.svip : _Tier.vip;
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _isVip => _tier == _Tier.vip;

  SubscriptionPlanModel? _resolveSelectedPlan() {
    final plans = ref.read(subscriptionPlansProvider).valueOrNull;
    if (plans == null || plans.isEmpty) return null;
    final tier = _isVip ? 'vip' : 'svip';
    final period = _plan == _Plan.weekly ? 'weekly' : 'yearly';
    return plans.where((p) => p.tier == tier && p.period == period).firstOrNull
        ?? plans.where((p) => p.tier == tier).firstOrNull;
  }

  void _onPurchaseTap() {
    final plan = _resolveSelectedPlan();
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan not available')),
      );
      return;
    }
    ref.read(iapProvider.notifier).purchaseSubscription(plan);
  }

  LinearGradient get _activeGradient => _isVip ? _vipGradient : _svipGradient;

  String get _buttonLabel {
    if (_isVip) {
      return _plan == _Plan.weekly ? 'Get Weekly VIP' : 'Get Yearly VIP';
    }
    return _plan == _Plan.weekly ? 'Get Weekly SVIP' : 'Get Lifetime SVIP';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<IapState>(iapProvider, (prev, next) {
      if (!mounted) return;
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
        ref.read(iapProvider.notifier).clearError();
      }
      if (next.lastPurchaseType == 'subscription' &&
          prev?.lastPurchaseType != 'subscription') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription activated!')),
        );
        ref.read(iapProvider.notifier).clearLastPurchase();
        context.go('/home');
      }
      if (next.lastPurchaseType == 'restore' &&
          prev?.lastPurchaseType != 'restore') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored!')),
        );
        ref.read(iapProvider.notifier).clearLastPurchase();
      }
    });

    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: video full screen
          const LocalBackgroundVideo(),

          // Layer 2: dimming gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.25, 0.55, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.35),
                    AppColors.backgroundPrimary.withOpacity(0.92),
                    AppColors.backgroundPrimary,
                  ],
                ),
              ),
            ),
          ),

          // Layer 2.5: solid black bottom zone
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: screenH * 0.55,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.backgroundPrimary,
                    AppColors.backgroundPrimary,
                  ],
                  stops: [0.0, 0.18, 1.0],
                ),
              ),
            ),
          ),

          // Layer 3: content
          SafeArea(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenH - MediaQuery.of(context).padding.top,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => context.go('/home'),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenH * 0.10),
                    _buildTitle(),
                    const SizedBox(height: 16),
                    _buildTierToggle(),
                    const SizedBox(height: 12),
                    _buildFeaturesRow(),
                    const SizedBox(height: 12),
                    _buildPlanCards(),
                    _buildBottomSection(),
                    SizedBox(height: bottomPad + 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Trimvo ',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => _activeGradient.createShader(bounds),
              child: Text(
                _isVip ? 'VIP' : 'SVIP',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isVip
              ? 'Standard Access & Privileges'
              : 'Faster, Higher-Quality Results',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIP / SVIP TOGGLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTierToggle() {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildToggleTab(_Tier.vip, 'VIP'),
          _buildToggleTab(_Tier.svip, 'SVIP'),
        ],
      ),
    );
  }

  Widget _buildToggleTab(_Tier tier, String label) {
    final isActive = _tier == tier;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _tier = tier;
          _plan = _Plan.weekly;
        }),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(26)),
              color: isActive ? null : Colors.transparent,
            ),
            child: isActive
                ? Container(
                    decoration: BoxDecoration(
                      gradient: _activeGradient,
                      borderRadius: const BorderRadius.all(Radius.circular(26)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURES ROW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFeaturesRow() {
    final features = [
      (Icons.percent, Colors.green, '50%\nCost'),
      (Icons.bolt, Colors.amber, 'Instant\nQueue'),
      (Icons.hd_outlined, Colors.blue, 'Ultra\nHD'),
      (Icons.star, AppColors.svipGold, 'All\nTemplates'),
      (Icons.diamond, Colors.cyan, 'Huge\nBonus'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: features
            .asMap()
            .entries
            .map((e) => _FeatureItem(
                  icon: e.value.$1,
                  iconColor: e.value.$2,
                  label: e.value.$3,
                  gradient: _activeGradient,
                  dimmed: _isVip && e.key < 2,
                ))
            .toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAN CARDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPlanCards() {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: plansAsync.when(
          loading: () => _buildCardsShimmer(),
          error: (_, __) => _isVip ? _buildVipCardsFallback() : _buildSvipCardsFallback(),
          data: (plans) {
            final tier = _isVip ? 'vip' : 'svip';
            final filtered = plans.where((p) => p.tier == tier).toList()
              ..sort((a, b) {
                const order = ['lifetime', 'yearly', 'weekly'];
                return order.indexOf(a.period).compareTo(order.indexOf(b.period));
              });
            if (filtered.isEmpty) {
              return _isVip ? _buildVipCardsFallback() : _buildSvipCardsFallback();
            }
            return _buildDynamicCards(filtered);
          },
        ),
      ),
    );
  }

  Widget _buildCardsShimmer() {
    return Column(
      key: const ValueKey('shimmer'),
      children: [
        _cardShimmer(),
        const SizedBox(height: 12),
        _cardShimmer(),
      ],
    );
  }

  Widget _cardShimmer() {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildDynamicCards(List<SubscriptionPlanModel> plans) {
    final tierKey = _isVip ? 'vip' : 'svip';
    // Select the first plan as default if nothing selected yet
    final selectedPeriod = _plan == _Plan.yearly ? 'yearly' : _plan == _Plan.weekly ? 'weekly' : 'lifetime';

    return Column(
      key: ValueKey(tierKey),
      children: [
        for (var i = 0; i < plans.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Builder(builder: (_) {
            final p = plans[i];
            final isSelected = p.period == selectedPeriod ||
                (i == 0 && !plans.any((x) => x.period == selectedPeriod));
            return _PlanCard(
              title: p.name,
              price: p.priceDisplay,
              billingInfo: p.billingInfo,
              bonusAmount: '+${p.gemsBonus}',
              bonusLabel: p.badgeText != null ? 'BONUS' : 'INCLUDED',
              isSelected: isSelected,
              gradient: _activeGradient,
              badgeText: p.badgeText,
              badgeGradient: _isVip ? _vipBadgeGradient : null,
              onTap: () => setState(() {
                if (p.period == 'weekly') {
                  _plan = _Plan.weekly;
                } else {
                  _plan = _Plan.yearly;
                }
              }),
            );
          }),
        ],
      ],
    );
  }

  // ── Fallback hardcoded cards (shown on API error) ──────────────────────────

  Widget _buildVipCardsFallback() {
    final plansAsync = ref.read(subscriptionPlansProvider);
    final currency = plansAsync.valueOrNull
        ?.firstOrNull
        ?.priceDisplay
        .replaceAll(RegExp(r'[\d\s,.]'), '')
        .trim() ?? '';

    String fmt(String amount) => currency.isNotEmpty ? '$amount $currency' : amount;

    return Column(
      key: const ValueKey('vip'),
      children: [
        _PlanCard(
          title: 'Yearly VIP',
          price: fmt('2 099,99'),
          billingInfo: '${fmt('2 099,99')}/year  ·  Billed yearly',
          bonusAmount: '+3000',
          bonusLabel: 'BONUS',
          isSelected: _plan == _Plan.yearly,
          gradient: _activeGradient,
          badgeText: '🏷  50% OFF',
          badgeGradient: _vipBadgeGradient,
          onTap: () => setState(() => _plan = _Plan.yearly),
        ),
        const SizedBox(height: 12),
        _PlanCard(
          title: 'Weekly VIP',
          price: fmt('419,99'),
          billingInfo: '${fmt('419,99')}/week  ·  Billed weekly',
          bonusAmount: '+400',
          bonusLabel: 'INCLUDED',
          isSelected: _plan == _Plan.weekly,
          gradient: _activeGradient,
          onTap: () => setState(() => _plan = _Plan.weekly),
        ),
      ],
    );
  }

  Widget _buildSvipCardsFallback() {
    final plansAsync = ref.read(subscriptionPlansProvider);
    final currency = plansAsync.valueOrNull
        ?.firstOrNull
        ?.priceDisplay
        .replaceAll(RegExp(r'[\d\s,.]'), '')
        .trim() ?? '';

    String fmt(String amount) => currency.isNotEmpty ? '$amount $currency' : amount;

    return Column(
      key: const ValueKey('svip'),
      children: [
        _PlanCard(
          title: 'Lifetime SVIP',
          price: fmt('3 699,99'),
          billingInfo: 'Pay once, enjoy forever',
          bonusAmount: '+6000',
          bonusLabel: 'BONUS',
          isSelected: _plan == _Plan.yearly,
          gradient: _activeGradient,
          badgeText: '🔥  BEST VALUE',
          onTap: () => setState(() => _plan = _Plan.yearly),
        ),
        const SizedBox(height: 12),
        _PlanCard(
          title: 'Weekly SVIP',
          price: fmt('529,99'),
          billingInfo: '${fmt('529,99')}/week  ·  Billed weekly',
          bonusAmount: '+600',
          bonusLabel: 'INCLUDED',
          isSelected: _plan == _Plan.weekly,
          gradient: _activeGradient,
          onTap: () => setState(() => _plan = _Plan.weekly),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          // Cancel / secure line
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isVip ? Icons.access_time_rounded : Icons.security_rounded,
                color: AppColors.textSecondary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                _isVip
                    ? 'Cancel anytime'
                    : 'Secure payments via App Store',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // CTA button
          _buildCTAButton(),
          const SizedBox(height: 16),
          // Footer links
          _buildFooterLinks(),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    final iapState = ref.watch(iapProvider);
    final isLoading = iapState.isLoading;

    return GestureDetector(
      onTap: isLoading ? null : _onPurchaseTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: _activeGradient,
          borderRadius: BorderRadius.circular(32),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isVip ? Colors.white : Colors.black,
                ),
              )
            : Text(
                _buttonLabel,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isVip ? Colors.white : Colors.black,
                ),
              ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    const textStyle = TextStyle(
      color: AppColors.textHint,
      fontSize: 12,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textHint,
    );
    const sepStyle = TextStyle(color: AppColors.textHint, fontSize: 12);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.push('/terms'),
          child: const Text('Terms', style: textStyle),
        ),
        const Text('  •  ', style: sepStyle),
        GestureDetector(
          onTap: () => context.push('/privacy'),
          child: const Text('Privacy', style: textStyle),
        ),
        const Text('  •  ', style: sepStyle),
        GestureDetector(
          onTap: () => ref.read(iapProvider.notifier).restorePurchases(),
          child: const Text('Restore', style: textStyle),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.billingInfo,
    required this.bonusAmount,
    required this.bonusLabel,
    required this.isSelected,
    required this.gradient,
    required this.onTap,
    this.badgeText,
    this.badgeGradient,
  });

  final String title;
  final String price;
  final String billingInfo;
  final String bonusAmount;
  final String bonusLabel;
  final bool isSelected;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final String? badgeText;
  final LinearGradient? badgeGradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card body
          Container(
            margin: EdgeInsets.only(top: badgeText != null ? 12 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: isSelected
                  ? LinearGradient(
                      colors: gradient.colors,
                      begin: gradient.begin,
                      end: gradient.end,
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
            ),
            padding: const EdgeInsets.all(1.5),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: gradient.colors
                                .map((c) => c.withOpacity(0.5))
                                .toList(),
                            begin: gradient.begin,
                            end: gradient.end,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                price,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                billingInfo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isSelected
                                      ? gradient.colors.first
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.diamond,
                                  color: Colors.blue.shade300, size: 22),
                              const SizedBox(height: 2),
                              Text(
                                bonusAmount,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (b) =>
                                    gradient.createShader(b),
                                child: Text(
                                  bonusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Floating badge with gradient border
          if (badgeText != null)
            Positioned(
              top: 0,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  gradient: badgeGradient ?? gradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: badgeGradient ?? gradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE ITEM
// ═══════════════════════════════════════════════════════════════════════════════

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.gradient,
    this.dimmed = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final LinearGradient gradient;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dimmed
                  ? AppColors.backgroundCard.withOpacity(0.5)
                  : const Color(0xFF1A1A2E),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: dimmed
                  ? Icon(icon, color: AppColors.textHint, size: 24)
                  : ShaderMask(
                      shaderCallback: (bounds) => gradient.createShader(bounds),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: dimmed ? AppColors.textHint : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}


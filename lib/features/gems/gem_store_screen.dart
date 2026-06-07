import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/theme/app_gradients.dart';
import 'package:trimvo/models/gem_package_model.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:trimvo/providers/gem_packages_provider.dart';
import 'package:trimvo/providers/iap_provider.dart';

class GemStoreScreen extends ConsumerStatefulWidget {
  const GemStoreScreen({super.key});

  @override
  ConsumerState<GemStoreScreen> createState() => _GemStoreScreenState();
}

class _GemStoreScreenState extends ConsumerState<GemStoreScreen> {
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
      if (next.lastPurchaseType == 'gems' && prev?.lastPurchaseType != 'gems') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gems added to your balance!')),
        );
        ref.read(iapProvider.notifier).clearLastPurchase();
      }
      if (next.lastPurchaseType == 'restore' && prev?.lastPurchaseType != 'restore') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored successfully!')),
        );
        ref.read(iapProvider.notifier).clearLastPurchase();
      }
    });

    final auth = ref.watch(authProvider);
    final gems = auth.gems;
    final isSvip = auth.isSvip;
    final packagesAsync = ref.watch(gemPackagesProvider);
    final iapLoading = ref.watch(iapProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBalance(gems),
                    if (!isSvip) ...[
                      const SizedBox(height: 16),
                      _buildSvipBanner(context),
                    ],
                    const SizedBox(height: 20),
                    packagesAsync.when(
                      loading: () => const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accentPurple),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (packages) =>
                          _buildPackagesSection(context, packages, iapLoading),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: iapLoading
                          ? null
                          : () => ref.read(iapProvider.notifier).restorePurchases(),
                      child: Text(
                        'Restore Purchases',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: iapLoading
                              ? AppColors.textHint
                              : AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: iapLoading
                              ? AppColors.textHint
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.backgroundCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Gem Store',
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

  Widget _buildBalance(int gems) {
    return Column(
      children: [
        Text(
          'CURRENT BALANCE',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond, color: AppColors.gemBlue, size: 28),
            const SizedBox(width: 8),
            Text(
              '$gems',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSvipBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/paywall?svip=true'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppGradients.svipBadge,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '👑 Unlock SVIP',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.backgroundPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate videos for 50% fewer gems + Exclusive Perks',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.backgroundPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'UPGRADE',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.svipGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagesSection(
      BuildContext context, List<GemPackageModel> packages, bool iapLoading) {
    final sorted = List<GemPackageModel>.from(packages)
      ..sort((a, b) => a.order.compareTo(b.order));
    final regular = sorted.where((p) => !p.isPopular).toList();
    final popular = sorted.where((p) => p.isPopular).toList();

    return Column(
      children: [
        if (regular.isNotEmpty)
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: regular
                .map((p) => _GemPackageCard(
                      package: p,
                      isLoading: iapLoading,
                      onTap: () =>
                          ref.read(iapProvider.notifier).purchaseGemPackage(p),
                    ))
                .toList(),
          ),
        for (final p in popular) ...[
          const SizedBox(height: 12),
          _GemPackageCard(
            package: p,
            fullWidth: true,
            isLoading: iapLoading,
            onTap: () =>
                ref.read(iapProvider.notifier).purchaseGemPackage(p),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GEM PACKAGE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _GemPackageCard extends StatelessWidget {
  const _GemPackageCard({
    required this.package,
    required this.onTap,
    this.fullWidth = false,
    this.isLoading = false,
  });

  final GemPackageModel package;
  final VoidCallback onTap;
  final bool fullWidth;
  final bool isLoading;

  String get _priceLabel {
    final amount = package.price % 1 == 0
        ? package.price.toInt().toString()
        : package.price.toStringAsFixed(2);
    switch (package.currency) {
      case 'USD':
        return '\$$amount';
      case 'EUR':
        return '€$amount';
      default:
        return '$amount ${package.currency}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fullWidth) return _buildFullWidth(context);
    return _buildGrid(context);
  }

  Widget _buildGrid(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond, color: AppColors.gemBlue, size: 28),
            const SizedBox(height: 6),
            Text(
              '${package.gemsAmount}',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (package.bonusGems > 0)
              Text(
                '+${package.bonusGems} FREE',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.svipGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (package.label != null)
              Text(
                package.label!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            const Spacer(),
            _buildPriceButton(isPopular: false),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidth(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.diamond, color: AppColors.gemBlue, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.svipGoldDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'MOST POPULAR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${package.gemsAmount}',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (package.bonusGems > 0)
                    Text(
                      '+${package.bonusGems} FREE',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.svipGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            _buildPriceButton(isPopular: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceButton({required bool isPopular}) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentPurple),
      );
    }
    if (isPopular) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppGradients.svipBadge,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _priceLabel,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.backgroundPrimary,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          _priceLabel,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.backgroundPrimary,
          ),
        ),
      ),
    );
  }
}

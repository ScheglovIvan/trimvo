import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/features/auth/login_bottom_sheet.dart';
import 'package:trimvo/providers/auth_provider.dart';

void showProfileBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Consumer(
      builder: (_, ref, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authProvider.notifier).refreshBalance();
        });
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetContext, scrollController) => _ProfileSheetContent(
            scrollController: scrollController,
            onUpgradeTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/paywall?svip=true');
            },
            onAddGemsTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/gems');
            },
          ),
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHEET CONTENT
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileSheetContent extends ConsumerWidget {
  const _ProfileSheetContent({
    required this.scrollController,
    required this.onUpgradeTap,
    required this.onAddGemsTap,
  });

  final ScrollController scrollController;
  final VoidCallback onUpgradeTap;
  final VoidCallback onAddGemsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          const _DragHandle(),
          _ProfileRow(auth: auth, onSignInTap: () async {
            Navigator.of(context).pop();
            await showLoginBottomSheet(context);
          }),
          _SvipBanner(onTap: onUpgradeTap),
          _GemsRow(gems: auth.gems, onAddTap: onAddGemsTap),
          _MenuSection(
            isLoggedIn: auth.isLoggedIn,
            onSignOut: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAG HANDLE
// ═══════════════════════════════════════════════════════════════════════════════

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.auth, required this.onSignInTap});

  final AuthState auth;
  final VoidCallback onSignInTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: auth.isLoggedIn ? null : onSignInTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF2A1A3E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.isLoggedIn ? (auth.email ?? 'User') : 'Guest',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (auth.userId != null)
                    Text(
                      'ID: ${auth.userId}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (!auth.isLoggedIn) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Tap to sign in & save your data',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 24),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SVIP UPGRADE BANNER
// ═══════════════════════════════════════════════════════════════════════════════

class _SvipBanner extends StatelessWidget {
  const _SvipBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B2DB8), Color(0xFF8B47F5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Trimvo ',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.svipGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SVIP',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A0800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock HD, Fast Pass & All Templates',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'UPGRADE',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentPurpleLight,
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
// MY GEMS ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _GemsRow extends StatelessWidget {
  const _GemsRow({required this.gems, required this.onAddTap});

  final int gems;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.diamond, color: Colors.blue, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My Gems',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$gems',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentPurpleLight,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentPurpleLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Add',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MENU SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.isLoggedIn, required this.onSignOut});

  final bool isLoggedIn;
  final VoidCallback onSignOut;

  static const _staticItems = [
    ('✍️', 'Feedback', ''),
    ('💬', 'Join Discord for real-time support', ''),
    ('📄', 'Privacy Policy', '/privacy'),
    ('📋', 'Terms of Service', '/terms'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          ..._staticItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MenuItem(emoji: item.$1, label: item.$2, route: item.$3),
            ),
          ),
          if (isLoggedIn) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onSignOut,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      child: Text('🚪', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.emoji,
    required this.label,
    required this.route,
  });

  final String emoji;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: route.isNotEmpty ? () => context.push(route) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

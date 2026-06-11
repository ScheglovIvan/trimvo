import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/theme/app_gradients.dart';
import 'package:trimvo/features/auth/login_bottom_sheet.dart';
import 'package:trimvo/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Same gradients as paywall_screen.dart so active-subscription card matches
// the selected plan card exactly.
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

void showProfileBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ProfileSheetWrapper(parentContext: context),
  );
}

class _ProfileSheetWrapper extends ConsumerStatefulWidget {
  const _ProfileSheetWrapper({required this.parentContext});

  final BuildContext parentContext;

  @override
  ConsumerState<_ProfileSheetWrapper> createState() =>
      _ProfileSheetWrapperState();
}

class _ProfileSheetWrapperState extends ConsumerState<_ProfileSheetWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (sheetContext, scrollController) => _ProfileSheetContent(
        scrollController: scrollController,
        onUpgradeTap: () {
          Navigator.of(sheetContext).pop();
          widget.parentContext.push('/paywall?svip=true');
        },
        onAddGemsTap: () {
          Navigator.of(sheetContext).pop();
          widget.parentContext.push('/gems');
        },
      ),
    );
  }
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
          _SvipBanner(auth: auth, onTap: onUpgradeTap),
          _GemsRow(gems: auth.gems, onAddTap: onAddGemsTap),
          _MenuSection(
            isLoggedIn: auth.isLoggedIn,
            onSignOut: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) Navigator.of(context).pop();
            },
            onDeleteAccount: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => const _DeleteAccountDialog(),
              );
              if (confirmed != true || !context.mounted) return;
              try {
                await ref.read(authProvider.notifier).deleteAccount();
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
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
                    if (!auth.isLoggedIn)
                      Text(
                        'Sign in to save your data',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (auth.isLoggedIn)
                const Icon(Icons.chevron_right, color: AppColors.textHint, size: 24),
            ],
          ),

          // Sign In button — only when not logged in
          if (!auth.isLoggedIn) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onSignInTap,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Sign In',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

// ═══════════════════════════════════════════════════════════════════════════════
// SVIP BANNER  (upgrade or active-subscription card)
// ═══════════════════════════════════════════════════════════════════════════════

class _SvipBanner extends StatelessWidget {
  const _SvipBanner({required this.auth, required this.onTap});

  final AuthState auth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return auth.hasActiveSubscription
        ? _ActiveSubscriptionCard(auth: auth)
        : _UpgradeBanner(onTap: onTap);
  }
}

// ─── Upgrade banner (no active subscription) ─────────────────────────────────

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});

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

// ─── Active subscription card ─────────────────────────────────────────────────
// Styled identically to the selected _PlanCard on the paywall screen:
// gradient 1.5 px border + backgroundCard inner + 50%-opacity gradient overlay.

class _ActiveSubscriptionCard extends StatelessWidget {
  const _ActiveSubscriptionCard({required this.auth});

  final AuthState auth;

  LinearGradient get _gradient => auth.isSvip ? _svipGradient : _vipGradient;

  String get _planLabel => auth.subscriptionStatus.toUpperCase();

  List<({IconData icon, String label})> get _perks {
    if (auth.isSvip) {
      return [
        (icon: Icons.diamond_outlined, label: '50% OFF'),
        (icon: Icons.bolt,             label: 'Fast Pass'),
        (icon: Icons.hd_outlined,      label: 'HD Quality'),
        (icon: Icons.collections,      label: 'All Templates'),
      ];
    }
    return [
      (icon: Icons.bolt,        label: 'Fast Pass'),
      (icon: Icons.collections, label: 'All Templates'),
      (icon: Icons.percent,     label: 'Discount'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final grad = _gradient;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      // Gradient border — same 1.5 px trick as _PlanCard
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            // Gradient background overlay at 50% — exact match to _PlanCard
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: grad.colors
                        .map((c) => c.withOpacity(0.50))
                        .toList(),
                    begin: grad.begin,
                    end: grad.end,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: plan name (left) + "Активна до [date]" (right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plan title with gradient text like paywall title
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Trimvo ',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (b) => grad.createShader(b),
                            child: Text(
                              _planLabel,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),

                  const SizedBox(height: 10),

                  // Perk chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _perks
                        .map((p) => _PerkChip(
                              icon: p.icon,
                              label: p.label,
                              gradient: grad,
                            ))
                        .toList(),
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

// ─── Perk chip ────────────────────────────────────────────────────────────────

class _PerkChip extends StatelessWidget {
  const _PerkChip({
    required this.icon,
    required this.label,
    required this.gradient,
  });

  final IconData icon;
  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (b) => gradient.createShader(b),
            child: Icon(icon, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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
  const _MenuSection({
    required this.isLoggedIn,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final bool isLoggedIn;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  static const _feedbackUrl =
      'mailto:support@trimvo.xyz?subject=Trimvo%20App%20Feedback';

  static const _routeItems = [
    ('📄', 'Privacy Policy', '/privacy'),
    ('📋', 'Terms of Service', '/terms'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MenuItem(
              emoji: '✍️',
              label: 'Send Feedback',
              onTap: () => launchUrl(Uri.parse(_feedbackUrl)),
            ),
          ),
          ..._routeItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MenuItem(
                emoji: item.$1,
                label: item.$2,
                onTap: () => context.push(item.$3),
              ),
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
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onDeleteAccount,
              child: Center(
                child: Text(
                  'Delete Account',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DELETE ACCOUNT DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete Account',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'All videos, gems and subscriptions will be permanently removed. This cannot be undone.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Type DELETE to confirm',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textHint,
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: AppColors.backgroundCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (v) {
                final ok = v.trim() == 'DELETE';
                if (ok != _confirmed) setState(() => _confirmed = ok);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _confirmed
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 44,
                      decoration: BoxDecoration(
                        color: _confirmed
                            ? Colors.redAccent
                            : AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Delete',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _confirmed
                              ? Colors.white
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

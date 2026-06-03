import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildContent(),
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
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Terms of Service',
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

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _body(
          'Last updated: January 1, 2025\n\n'
          'Please read these Terms of Service ("Terms") carefully before using the '
          'Trimvo mobile application operated by Trimvo ("us", "we", or "our"). '
          'By accessing or using the app you agree to be bound by these Terms.',
        ),
        _section('1. Acceptance of Terms'),
        _body(
          'By downloading, installing, or using Trimvo you confirm that you are at '
          'least 13 years old (or 16 in the EU) and that you agree to these Terms. '
          'If you do not agree, do not use the app.',
        ),
        _section('2. License to Use'),
        _body(
          'We grant you a limited, non-exclusive, non-transferable, revocable licence '
          'to use Trimvo for your personal, non-commercial purposes. You may not:\n\n'
          '• Copy, modify, or distribute the app or its content.\n'
          '• Reverse-engineer or attempt to extract source code.\n'
          '• Use the app to develop a competing service.\n'
          '• Circumvent any security or access controls.',
        ),
        _section('3. Subscriptions and In-App Purchases'),
        _body(
          'Trimvo offers VIP and SVIP subscription plans billed on a weekly or '
          'yearly basis, as well as one-time Lifetime plans. All purchases are '
          'processed through Apple App Store.\n\n'
          '• Subscriptions automatically renew unless cancelled at least 24 hours '
          'before the end of the current period.\n'
          '• Prices may vary by region and are displayed at the time of purchase.\n'
          '• Refunds are handled by Apple in accordance with their policies.\n'
          '• If an AI generation task fails, we provide a 100% gem refund.',
        ),
        _section('4. User Content'),
        _body(
          'You retain ownership of the photos and media you upload. By using the app '
          'you grant us a limited licence to process your media solely for the purpose '
          'of providing the AI generation service. We do not claim ownership of your '
          'content and we do not use it to train AI models without explicit consent.',
        ),
        _section('5. Prohibited Uses'),
        _body(
          'You agree not to use Trimvo to:\n\n'
          '• Upload content that is illegal, harmful, hateful, or infringes third-party rights.\n'
          '• Generate deepfakes or non-consensual intimate imagery.\n'
          '• Spam, harass, or defraud other users.\n'
          '• Violate any applicable local, national, or international law.\n\n'
          'We reserve the right to suspend or terminate accounts that violate these rules.',
        ),
        _section('6. AI-Generated Content'),
        _body(
          'AI-generated content is provided "as is" and may vary in quality. We do not '
          'guarantee that generated content will meet your expectations. You are solely '
          'responsible for how you use AI-generated content and must ensure you have '
          'the rights to any images you upload.',
        ),
        _section('7. Disclaimers'),
        _body(
          'Trimvo is provided on an "as is" and "as available" basis without warranties '
          'of any kind, either express or implied, including but not limited to '
          'merchantability, fitness for a particular purpose, or non-infringement.\n\n'
          'We do not warrant that the app will be uninterrupted, error-free, or free '
          'of viruses or other harmful components.',
        ),
        _section('8. Limitation of Liability'),
        _body(
          'To the fullest extent permitted by law, Trimvo shall not be liable for '
          'any indirect, incidental, special, consequential, or punitive damages '
          'arising out of or related to your use of the app. Our total liability '
          'shall not exceed the amount you paid us in the 12 months preceding the claim.',
        ),
        _section('9. Changes to Terms'),
        _body(
          'We reserve the right to modify these Terms at any time. We will notify you '
          'of material changes via in-app notification. Continued use of the app after '
          'changes take effect constitutes acceptance of the revised Terms.',
        ),
        _section('10. Contact Us'),
        _body(
          'If you have any questions about these Terms, please contact us:\n\n'
          'Trimvo Support\nEmail: legal@hypcut.app',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        height: 1.6,
        color: AppColors.textPrimary,
      ),
    );
  }
}

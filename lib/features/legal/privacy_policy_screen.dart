import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
              'Privacy Policy',
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
          'Last updated: June 11, 2026\n\n'
          'Trimvo ("we", "our", or "us") is committed to protecting your privacy. '
          'This Privacy Policy explains how we collect, use, disclose, and safeguard '
          'your information when you use our mobile application.',
        ),
        _section('1. Information We Collect'),
        _body(
          'We may collect the following types of information:\n\n'
          '• Account information: email address and password (hashed) that you provide '
          'when registering.\n'
          '• Device information: device type, operating system, unique device identifiers.\n'
          '• Usage data: features used, content created, time spent in the app.\n'
          '• Photos and media: images you choose to upload for AI processing. Uploaded '
          'media is stored on our secure servers for the duration of your account to '
          'enable your generation history; you may delete it at any time.\n'
          '• Generated content: AI-generated videos and images produced by the service, '
          'stored in your account history.\n'
          '• Purchase information: subscription status and transaction identifiers via '
          'Apple App Store (we do not store payment card details).',
        ),
        _section('2. How We Use Your Information'),
        _body(
          'We use your information to:\n\n'
          '• Provide and improve the Trimvo service.\n'
          '• Process AI video and image generation requests.\n'
          '• Store and display your generation history.\n'
          '• Manage your subscription and in-app purchases.\n'
          '• Send important service notifications.\n'
          '• Analyse usage patterns to improve the app experience.\n'
          '• Comply with legal obligations.',
        ),
        _section('3. Sharing With Third Parties'),
        _body(
          'We do not sell your personal data. We may share information with:\n\n'
          '• AI processing partners who assist in generating content (under strict '
          'data processing agreements).\n'
          '• Cloud storage providers who host your media and generated content.\n'
          '• Payment processors (Apple) who handle transactions on our behalf.\n'
          '• Law enforcement or regulatory authorities when required by law.',
        ),
        _section('4. Data Retention'),
        _body(
          'We retain your account data, uploaded media, and generated content for as '
          'long as your account is active or as required by law. You may delete '
          'individual generated items from your history at any time. You may request '
          'full deletion of your account and all associated data through the app '
          '(Profile → Delete Account) or by contacting us.',
        ),
        _section("5. Children's Privacy"),
        _body(
          'Trimvo is not directed to children under the age of 13 (or 16 in the EU). '
          'We do not knowingly collect personal data from children. If you believe '
          'we have inadvertently collected such data, please contact us immediately '
          'and we will delete it promptly.',
        ),
        _section('6. Security'),
        _body(
          'We implement industry-standard security measures including encryption in '
          'transit (TLS) and at rest. However, no method of transmission over the '
          'Internet is 100% secure and we cannot guarantee absolute security.',
        ),
        _section('7. Your Rights'),
        _body(
          'Depending on your jurisdiction you may have the right to:\n\n'
          '• Access the personal data we hold about you.\n'
          '• Request correction or deletion of your data.\n'
          '• Object to or restrict processing of your data.\n'
          '• Data portability.\n\n'
          'To exercise these rights, use the in-app Delete Account feature or '
          'contact us at the email below.',
        ),
        _section('8. Changes to This Policy'),
        _body(
          'We may update this Privacy Policy from time to time. We will notify you '
          'of material changes via in-app notification or email. Continued use of '
          'the app after changes constitutes acceptance of the updated policy.',
        ),
        _section('9. Contact Us'),
        _body(
          'If you have any questions about this Privacy Policy, please contact us:\n\n'
          'Trimvo\nEmail: support@trimvo.xyz',
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

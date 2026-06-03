import 'package:go_router/go_router.dart';
import 'package:trimvo/features/create/create_image_screen.dart';
import 'package:trimvo/features/onboarding/onboarding_screen.dart';
import 'package:trimvo/features/home/home_screen.dart';
import 'package:trimvo/features/create/upload_screen.dart';
import 'package:trimvo/features/create/template_upload_screen.dart';
import 'package:trimvo/features/create/generating_screen.dart';
import 'package:trimvo/features/create/result_screen.dart';
import 'package:trimvo/features/paywall/paywall_screen.dart';
import 'package:trimvo/features/settings/settings_screen.dart';
import 'package:trimvo/features/templates/template_detail_screen.dart';
import 'package:trimvo/features/categories/category_screen.dart';
import 'package:trimvo/features/legal/privacy_policy_screen.dart';
import 'package:trimvo/features/legal/terms_of_service_screen.dart';
import 'package:trimvo/features/gems/gem_store_screen.dart';
import 'package:trimvo/features/history/history_screen.dart';
import 'package:trimvo/features/history/work_video_screen.dart';
import 'package:trimvo/features/history/work_image_screen.dart';
import 'package:trimvo/features/templates/template_swipe_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'template/:id',
          builder: (context, state) => TemplateDetailScreen(
            id: Uri.decodeComponent(state.pathParameters['id'] ?? ''),
          ),
        ),
        GoRoute(
          path: 'category/:name',
          builder: (context, state) => CategoryScreen(
            name: Uri.decodeComponent(state.pathParameters['name'] ?? ''),
            categoryId: state.uri.queryParameters['id'],
            trending: state.uri.queryParameters['trending'] == 'true',
          ),
        ),
        GoRoute(
          path: 'paywall',
          builder: (context, state) => PaywallScreen(
            initialSvip: state.uri.queryParameters['svip'] == 'true',
          ),
        ),
        GoRoute(
          path: 'create-image',
          builder: (context, state) => const CreateImageScreen(),
        ),
        GoRoute(
          path: 'gems',
          builder: (context, state) => const GemStoreScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: 'privacy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: 'terms',
          builder: (context, state) => const TermsOfServiceScreen(),
        ),
        GoRoute(
          path: 'upload',
          builder: (context, state) {
            final templateId = state.uri.queryParameters['templateId'];
            if (templateId != null && templateId.isNotEmpty) {
              return TemplateUploadScreen(templateId: templateId);
            }
            return UploadScreen(templateId: templateId);
          },
        ),
        GoRoute(
          path: 'create',
          builder: (context, state) {
            final templateId = state.uri.queryParameters['templateId'];
            if (templateId != null && templateId.isNotEmpty) {
              return TemplateUploadScreen(templateId: templateId);
            }
            return UploadScreen(templateId: templateId);
          },
        ),
        GoRoute(
          path: 'remix',
          builder: (context, state) => const ResultScreen(),
        ),
        GoRoute(
          path: 'generating',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return GeneratingScreen(
              jobId: state.uri.queryParameters['jobId'],
              backgroundImagePath: extra['imagePath']?.toString(),
              jobType: extra['jobType']?.toString(),
            );
          },
        ),
        GoRoute(
          path: 'result',
          builder: (context, state) => ResultScreen(
            resultUrl: state.uri.queryParameters['resultUrl'],
            originalUrl: state.uri.queryParameters['originalUrl'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) {
        final templateId = state.uri.queryParameters['templateId'];
        if (templateId != null && templateId.isNotEmpty) {
          return TemplateUploadScreen(templateId: templateId);
        }
        return UploadScreen(templateId: templateId);
      },
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) {
        final templateId = state.uri.queryParameters['templateId'];
        if (templateId != null && templateId.isNotEmpty) {
          return TemplateUploadScreen(templateId: templateId);
        }
        return UploadScreen(templateId: templateId);
      },
    ),
    GoRoute(
      path: '/remix',
      builder: (context, state) => const ResultScreen(),
    ),
    GoRoute(
      path: '/generating',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return GeneratingScreen(
          jobId: state.uri.queryParameters['jobId'],
          backgroundImagePath: extra['imagePath']?.toString(),
          jobType: extra['jobType']?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/work-video',
      builder: (context, state) {
        final extra = state.extra as Map<String, String?>? ?? {};
        return WorkVideoScreen(
          videoUrl: extra['videoUrl'] ?? '',
          thumbUrl: extra['thumbUrl'],
        );
      },
    ),
    GoRoute(
      path: '/work-image',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final urls = (extra['imageUrls'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            [];
        return WorkImageScreen(
          imageUrls: urls,
          initialIndex:
              (extra['initialIndex'] as int?) ?? 0,
        );
      },
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) => ResultScreen(
        resultUrl: state.uri.queryParameters['resultUrl'],
        originalUrl: state.uri.queryParameters['originalUrl'],
      ),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => PaywallScreen(
        initialSvip: state.uri.queryParameters['svip'] == 'true',
      ),
    ),
    GoRoute(
      path: '/create-image',
      builder: (context, state) => const CreateImageScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/template/:id',
      builder: (context, state) => TemplateDetailScreen(
        id: Uri.decodeComponent(state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/category/:name',
      builder: (context, state) => CategoryScreen(
        name: Uri.decodeComponent(state.pathParameters['name'] ?? ''),
        categoryId: state.uri.queryParameters['id'],
        trending: state.uri.queryParameters['trending'] == 'true',
      ),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
    GoRoute(
      path: '/gems',
      builder: (context, state) => const GemStoreScreen(),
    ),
    GoRoute(
      path: '/template-swipe',
      builder: (context, state) {
        final categoryId = state.uri.queryParameters['categoryId'];
        final trending = state.uri.queryParameters['trending'] == 'true';
        final initialIndex =
            int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0;
        return TemplateSwipeScreen(
          categoryId: categoryId,
          trending: trending,
          initialIndex: initialIndex,
        );
      },
    ),
  ],
);

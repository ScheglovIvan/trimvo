# HypeCut — Project Documentation

## App Overview

**HypeCut** is an AI-powered video generation app. Users browse template clips, select a template, upload a photo (or two), and receive a generated short-form video within seconds. The app targets creators who want stylized social media clips without manual editing.

- **App name**: HypeCut
- **Bundle ID**: hyper_cut
- **Version**: 1.0.0+1
- **Flutter SDK**: 3.x (tested on 3.19.6)
- **Dart SDK constraint**: `>=3.3.4 <4.0.0`
- **Target platforms**: Android (confirmed, dev device Samsung Galaxy S24 FE, ID `R5CY23GXQ2D`), iOS (implied by pubspec structure and `appleProductId` in gem packages)
- **Orientation**: Portrait only (locked in `main.dart`)
- **Theme**: Dark only (`AppTheme.dark`)

---

## Tech Stack

| Package | Version | Purpose |
|---|---|---|
| flutter_riverpod | ^2.5.1 | State management (ProviderScope, FutureProvider, StateNotifier) |
| go_router | ^13.2.0 | Declarative navigation |
| google_fonts | ^6.2.1 | Inter font throughout the app |
| http | ^1.2.0 | REST API calls |
| shared_preferences | ^2.2.3 | Auth token persistence, liked templates |
| cached_network_image | ^3.3.1 | Image loading with disk cache |
| flutter_cache_manager | ^3.3.0 | Custom image and video disk caches |
| flutter_animate | ^4.5.0 | Shimmer placeholder animations |
| video_player | ^2.8.6 | Template preview videos, paywall background, favorites tab |
| image_picker | ^1.1.2 | Photo selection for video generation |
| cupertino_icons | ^1.0.6 | iOS-style icons |

---

## Project Structure

```
lib/
  core/
    constants/   — ApiConstants (devHost, base URLs, fixUrl)
    router/      — GoRouter definition (all routes)
    theme/       — AppColors, AppGradients, AppRadius, AppSpacing, AppTextStyles, AppTheme
    widgets/     — AppBackground (global scaffold wrapper)
  features/
    auth/        — LoginBottomSheet (email/password, register/login)
    categories/  — CategoryScreen (grid of templates for one category)
    create/      — UploadScreen, TemplateUploadScreen, GeneratingScreen, ResultScreen, FaceDetectScreen, PhotoPickerSheet
    gems/        — GemStoreScreen (purchase gem packages)
    history/     — HistoryScreen (tabs: Generated, Drafts, Favorites)
    home/        — HomeScreen (featured carousel + category rows)
    legal/       — PrivacyPolicyScreen, TermsOfServiceScreen
    onboarding/  — OnboardingScreen (animated intro, SmartVideoGrid background)
    paywall/     — PaywallScreen (VIP / SVIP subscription plans)
    profile/     — ProfileBottomSheet (balance, settings, logout)
    settings/    — SettingsScreen (placeholder)
    templates/   — TemplateDetailScreen, TemplateSwipeScreen, ReportBottomSheet
  models/
    category_model.dart      — CategoryModel (id, name, order)
    gem_package_model.dart   — GemPackageModel (pricing, IAP product IDs)
    job_model.dart           — JobModel (generation job status tracking)
    report_reason.dart       — ReportReason enum with labels and API values
    template_model.dart      — TemplateModel (media URLs, slots, cost)
  providers/
    active_video_provider.dart   — StateProvider<String?> (active template ID for GIF)
    auth_provider.dart           — AuthNotifier / AuthState (login, register, token refresh)
    categories_provider.dart     — FutureProvider<List<CategoryModel>>
    gem_packages_provider.dart   — FutureProvider<List<GemPackageModel>> (with fallback)
    jobs_provider.dart           — JobsNotifier / JobsState (create, poll, list)
    likes_provider.dart          — LikesNotifier / Set<String> (SharedPreferences backed)
    onboarding_provider.dart     — FutureProvider<List<String>> (onboarding video URLs)
    pricing_provider.dart        — FutureProvider<PricingModel> (gem cost multipliers)
    templates_provider.dart      — FutureProvider.family<List<TemplateModel>, TemplatesParams>
  services/
    api_service.dart    — All HTTP calls, ApiException, Bearer token injection
  shared/
    utils/
      video_utils.dart         — initCachedVideoController (cache-first video loading)
    widgets/
      app_bottom_nav.dart      — Bottom navigation bar (Home / History)
      app_cache_manager.dart   — AppCacheManager (images), VideoCacheManager (video)
      custom_button.dart       — Primary / secondary solid button
      dynamic_video_grid.dart  — Scrolling 3-column video grid (onboarding background)
      gradient_button.dart     — Purple gradient CTA button
      local_background_video.dart — Local asset video player (paywall / onboarding)
      plays_counter.dart       — Play count badge (icon + text)
      scrolling_gif_grid.dart  — Static GIF-based scrolling background (fallback)
      smart_video_grid.dart    — Chooses DynamicVideoGrid or ScrollingGifGrid based on API
      svip_badge.dart          — 👑 SVIP gradient badge widget
      template_card.dart       — AspectRatio 3:4 thumbnail card + ShimmerPlaceholder
assets/
  images/templates/   — local template thumbnail fallbacks
  videos/welcome.mp4  — local video used as paywall/onboarding background
```

---

## Backend Integration

| Setting | Value |
|---|---|
| API base URL | `http://10.103.239.166:8000/v1` |
| MinIO base URL | `http://10.103.239.166:9000` |
| devHost | `10.103.239.166` (hardcoded in `api_constants.dart`) |
| Auth | `Authorization: Bearer <token>` header on all requests |
| Timeout | 30 seconds (`ApiConstants.requestTimeout`) |
| Max retries | 3 (constant, not yet wired to retry logic) |

### URL Rewriting

`ApiConstants.fixUrl(url)` replaces:
- `http://localhost:9000` → `http://10.103.239.166:9000`
- `http://localhost:8000` → `http://10.103.239.166:8000`

Applied in `TemplateModel.fromJson` on all media URL fields, and in `ApiService.getOnboardingVideos()`.

> **⚠ Known issue**: `devHost` is a hardcoded LAN IP. It must be updated whenever the developer switches WiFi networks.

---

## API Endpoints

| Method | Path | Purpose | Key params |
|---|---|---|---|
| POST | `/auth/register` | Register new user | `email`, `password` |
| POST | `/auth/login` | Login, returns access + refresh tokens | `email`, `password` |
| GET | `/auth/me` | Get current user (id, gems, subscription_status) | Bearer token |
| POST | `/auth/refresh` | Refresh expired access token | `refresh_token` |
| GET | `/templates` | Paginated template list | `page`, `per_page`, `category`, `trending` |
| GET | `/templates/:id` | Single template detail | path param `id` |
| POST | `/reports` | Submit abuse report | `template_id`, `reason` |
| GET | `/categories` | List all categories | — |
| GET | `/categories/:id/templates` | Templates for a category | path param `id` |
| GET | `/gem-packages` | Available gem purchase packages | — |
| GET | `/subscription-plans` | Subscription plan definitions | — |
| GET | `/pricing` | Gem cost multipliers | — |
| POST | `/jobs` | Create a video generation job | `template_id`, `options` |
| GET | `/jobs/:id` | Poll job status | path param `id` |
| GET | `/jobs` | List current user's jobs | — |
| GET | `/config/onboarding-video` | Onboarding background video URL | — |

---

## Caching Strategy

| Layer | Mechanism | TTL / Limit |
|---|---|---|
| Template lists | In-memory `Map<TemplatesParams, (List, DateTime)>` | 5 minutes |
| Individual templates | `templateDetailProvider` — no TTL, re-fetched on each navigation | — |
| Images | `AppCacheManager` (flutter_cache_manager disk cache) | 7 days, 300 objects |
| Video previews | `VideoCacheManager` via `initCachedVideoController` | 3 days, 50 objects |
| Background video | `VideoPlayerController.asset('assets/videos/welcome.mp4')` | Local, no cache needed |

`clearTemplatesCache()` is called on pull-to-refresh in `HomeScreen`.

---

## Navigation (GoRouter)

Initial location: `/`

| Path | Screen | Notes |
|---|---|---|
| `/` | `OnboardingScreen` | App entry point |
| `/home` | `HomeScreen` | Main feed (featured + category rows) |
| `/home/template/:id` | `TemplateDetailScreen` | Template detail, URL-decoded id |
| `/home/category/:name` | `CategoryScreen` | Query: `?id=<uuid>&trending=<bool>` |
| `/home/paywall` | `PaywallScreen` | Also available at `/paywall` |
| `/home/gems` | `GemStoreScreen` | Also at `/gems` |
| `/home/settings` | `SettingsScreen` | Also at `/settings` |
| `/home/privacy` | `PrivacyPolicyScreen` | Also at `/privacy` |
| `/home/terms` | `TermsOfServiceScreen` | Also at `/terms` |
| `/home/upload` | `UploadScreen` or `TemplateUploadScreen` | Query: `?templateId=` selects screen |
| `/home/create` | same as upload | Alias |
| `/home/generating` | `GeneratingScreen` | Query: `?jobId=` |
| `/home/result` | `ResultScreen` | — |
| `/home/remix` | `ResultScreen` | Alias |
| `/history` | `HistoryScreen` | Tabs: Generated / Drafts / Favorites |
| `/template-swipe` | `TemplateSwipeScreen` | Query: `?categoryId=&trending=&index=` |
| `/paywall` | `PaywallScreen` | Root-level alias |
| `/template/:id` | `TemplateDetailScreen` | Root-level alias |
| `/category/:name` | `CategoryScreen` | Root-level alias |
| `/generating` | `GeneratingScreen` | Root-level alias |
| `/result` | `ResultScreen` | Root-level alias |
| `/upload` / `/create` | Upload/TemplateUpload | Root-level aliases |

---

## Known Issues / TODOs

- **`devHost` is hardcoded** (`10.103.239.166`) — must be changed in `lib/core/constants/api_constants.dart` when the development machine's IP changes.
- `maxRetries = 3` constant in `ApiConstants` is declared but not wired into any retry logic.
- `SettingsScreen` is a placeholder stub with only a centered "Settings" text.
- `ResultScreen` in `/home/result` and `/remix` appears to be a legacy stub — it contains upload UI rather than displaying a completed video result.
- `DynamicVideoGrid` loads up to 15 videos directly via `VideoPlayerController.networkUrl` without using `VideoCacheManager`.

---

## Last Analyze

```
Analyzing hyper_cut...
No issues found! (ran in 5.5s)
```

_Run date: 2026-05-31_

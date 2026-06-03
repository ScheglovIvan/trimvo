# HypeCut — Architecture Documentation

## State Management

**Framework**: Riverpod 2.x with `ProviderScope` at the app root (`main.dart`).

**Patterns used**:
- `FutureProvider` / `FutureProvider.family` — async data fetching with loading/error/data states
- `StateNotifierProvider` — complex mutable state with business logic (auth, jobs, likes)
- `StateProvider` — simple single-value state (active video ID)

### Provider Inventory

| Provider | Type | Holds | Used In |
|---|---|---|---|
| `authProvider` | `StateNotifierProvider<AuthNotifier, AuthState>` | Login state, token, userId, gems, subscriptionStatus | All screens that need auth; `main.dart` for startup load |
| `activeVideoProvider` | `StateProvider<String?>` | Template ID currently showing its GIF preview in the featured carousel | `HomeScreen` featured carousel |
| `categoriesProvider` | `FutureProvider<List<CategoryModel>>` | All categories from API | `HomeScreen` category rows |
| `templatesProvider` | `FutureProvider.family<List<TemplateModel>, TemplatesParams>` | Paginated template list, keyed by params | `HomeScreen`, `CategoryScreen`, `TemplateSwipeScreen` |
| `templateDetailProvider` | `FutureProvider.family<TemplateModel, String>` | Single template by ID | `TemplateDetailScreen`, `HistoryScreen._FavoritesTab` |
| `gemPackagesProvider` | `FutureProvider<List<GemPackageModel>>` | Gem purchase packages (with hardcoded fallback) | `GemStoreScreen` |
| `jobsProvider` | `StateNotifierProvider<JobsNotifier, JobsState>` | Generation job list + active polling job | `GeneratingScreen`, `HistoryScreen`, `UploadScreen` |
| `likesProvider` | `StateNotifierProvider<LikesNotifier, Set<String>>` | Set of liked template IDs (SharedPreferences-backed) | `TemplateDetailScreen`, `TemplateSwipeScreen`, `HistoryScreen._FavoritesTab` |
| `onboardingVideosProvider` | `FutureProvider<List<String>>` | Onboarding background video URLs from API | `SmartVideoGrid` |
| `pricingProvider` | `FutureProvider<PricingModel>` | Gem cost multipliers from API (with fallback) | `TemplateUploadScreen` |

---

## Data Flow

### Main use case: Browse templates → tap → create video

1. **HomeScreen** mounts, watches `templatesProvider(TemplatesParams(trending: true))` for the featured carousel and `categoriesProvider` for the category rows.
2. `templatesProvider` checks the in-memory `_templateCache` map (5-minute TTL). On miss, calls `ApiService.getTemplates(trending: true, page: 1, perPage: 20)`.
3. API returns `{items: [...], total: N}`. Items are mapped to `List<TemplateModel>` with `fixUrl` applied to all media URLs. Result is stored in cache.
4. `HomeScreen` renders the featured carousel. As the user scrolls, `activeVideoProvider` is updated to the center card's template ID, triggering a GIF overlay on that card.
5. User taps a card → `context.push('/template-swipe?trending=true&index=$i')`.
6. **TemplateSwipeScreen** uses the same `templatesProvider` data (already cached). It initializes a `VideoPlayerController.networkUrl` for each visible card's `previewUrl`.
7. User taps "Use Template" → `context.push('/home/upload?templateId=$id')` → `TemplateUploadScreen`.
8. **TemplateUploadScreen** loads the template via `templateDetailProvider(id)` (separate fetch for full detail). Watches `pricingProvider` to display computed gem cost.
9. User picks a photo via `showPhotoPickerSheet` → `ImagePicker`, optionally confirms face via `showFaceDetectScreen`.
10. Tap "Generate" → checks `authProvider.isLoggedIn`. If not logged in, shows `LoginBottomSheet`. On login, `AuthNotifier.login()` sets `ApiService.token` and persists to SharedPreferences.
11. `jobsProvider.notifier.createJob(templateId, options)` → `POST /jobs` → returns `jobId`.
12. `context.push('/home/generating?jobId=$jobId')`.
13. **GeneratingScreen** calls `jobsProvider.notifier.pollJobStatus(jobId)` — a `Timer.periodic(2s)` that GETs `/jobs/$jobId` until `status == 'done'` or `'failed'`.
14. On done → `context.go('/result')`.

---

## Models

### `TemplateModel`
Fields: `id`, `title`, `description`, `thumbUrl`, `previewUrl`, `previewCompressedUrl`, `gifUrl`, `videoUrl`, `likes`, `plays`, `gemsCost` (default 200), `photoSlots` (default 1), `hasMaleSlot`, `hasFemaleSlot`.

All URL fields are passed through `ApiService.fixUrl()` in `fromJson`, rewriting localhost to the dev server IP.

### `CategoryModel`
Fields: `id`, `name`, `order`. Simple lookup model used to build the home screen category rows.

### `GemPackageModel`
Fields: `id`, `gemsAmount`, `bonusGems`, `price`, `currency`, `label`, `isPopular`, `appleProductId`, `googleProductId`, `order`.

`gemPackagesProvider` falls back to 5 hardcoded UAH packages if the API returns empty or throws.

### `JobModel`
Fields: `id`, `status`, `progress`, `resultUrl`, `error`, `gemsCost`, `templateId`, `createdAt`.

Computed getters: `isDone` (`status == 'done'`), `isFailed` (`status == 'failed'`), `isProcessing` (`status == 'processing' || 'queued'`).

### `PricingModel`
Fields: `basePer5s`, `basePer10s`, `multiplierStandard`, `multiplierHd`, `multiplierUltraHd`.

`calculate()` method: `templateBaseCost × qualityMultiplier × durationMultiplier`, halved (ceil) for SVIP users.

### `ReportReason` (enum)
11 values. Each has a `.label` (display text) and `.apiValue` (snake_case for API submission).

---

## Widget Architecture

### Template Card Layers (HomeScreen featured carousel, CategoryScreen grid)

```
Stack(fit: StackFit.expand)
  Layer 1: CachedNetworkImage(thumbUrl)      — always visible, shimmer placeholder while loading
  Layer 2: AnimatedOpacity → Image.network(gifUrl)  — shown only on center/active card
  Layer 3: RepaintBoundary → FittedBox → VideoPlayer — scroll-triggered, plays previewCompressedUrl
  Layer 4: DecoratedBox(gradient: AppGradients.cardOverlay)  — bottom dark gradient
  Layer 5: Positioned(bottom) → title + PlaysCounter
```

### HomeScreen Featured Carousel (`_FeaturedCarousel`)
- `PageView` of 9:16 aspect-ratio cards
- `activeVideoProvider` set to center card's template ID on page change
- Card tap → `TemplateSwipeScreen` at that index

### HomeScreen Category Rows (`_CategoryRowFromApi`)
- Horizontal `ListView` of `TemplateCard` (3:4 aspect ratio)
- One `VideoPlayerController` per row, plays the first visible card's `previewCompressedUrl`
- Scroll listener moves the active video to whichever card is first visible
- Lookahead: prefetches `firstVisibleIndex + 1` while scrolling
- `WidgetsBindingObserver`: pauses all video on app backgrounded, resumes on foreground

### CategoryScreen (`_VideoGridCard`)
- Infinite-scroll `GridView` (2 columns)
- Active indices set: `{0, 1}` on init, updated by scroll
- `WidgetsBindingObserver` for background pause

### HistoryScreen Favorites Tab
- `ScrollController` tracks scroll; `_onScroll` computes the center row and activates 3 controllers at a time
- Each `_FavoriteCard` has 3 layers: thumb / GIF (`AnimatedOpacity`) / video

### Shimmer Pattern
`ShimmerPlaceholder` (in `template_card.dart`) = `ColoredBox(backgroundCard)` + `flutter_animate` shimmer. Used in:
- `_ShimmerFeatured` (height 252) — featured carousel loading
- `_ShimmerRow` (height 200) — category row loading
- `CachedNetworkImage` `placeholder` on all image loads

---

## Video Strategy

| Context | Controller source | Notes |
|---|---|---|
| Onboarding background | `SmartVideoGrid` → `DynamicVideoGrid` (network) or `ScrollingGifGrid` (GIF fallback) | Falls back if API returns no URLs |
| Paywall / onboarding overlay | `LocalBackgroundVideo` (`VideoPlayerController.asset`) | Local `assets/videos/welcome.mp4`, looping, muted |
| Home featured GIF layer | `Image.network(gifUrl)` | Only center card, controlled by `activeVideoProvider` |
| Home category row video | `initCachedVideoController(previewCompressedUrl)` | 1 per row, cache-first |
| CategoryScreen grid video | `initCachedVideoController(previewCompressedUrl)` | Active indices set {0,1} |
| TemplateDetailScreen | `VideoPlayerController.networkUrl(previewUrl)` | Full quality, **with sound** (volume 1.0) |
| TemplateSwipeScreen | `VideoPlayerController.networkUrl(previewUrl)` | No cache, preloads ±1 from current index |
| HistoryScreen favorites | `initCachedVideoController(previewCompressedUrl)` | 3 active at a time, scroll-driven |

### `initCachedVideoController(url)`
1. `VideoCacheManager().downloadFile(url)` → gets local `File`
2. `VideoPlayerController.file(file)` → initialize → setLooping(true) → setVolume(0) → play
3. On any error, falls back to `VideoPlayerController.networkUrl(url)` with same settings
4. Returns `null` if both paths throw

---

## Auth Flow

1. **App start** (`_HyperCutAppState.initState`): calls `authProvider.notifier.loadFromStorage()`
   - Reads `auth_token` from SharedPreferences
   - If found: sets `ApiService.token`, calls `GET /auth/me` to refresh gems + subscription
   - On 401: attempts token refresh via `POST /auth/refresh` with stored `refresh_token`
   - On refresh failure: clears storage, resets to unauthenticated state
2. **Login/Register**: via `LoginBottomSheet` → `AuthNotifier.login()` or `.register()`
   - Stores `access_token`, `refresh_token`, `email`, `user_id` in SharedPreferences
   - Immediately calls `GET /auth/me` for gems + subscription status
3. **Balance refresh**: `refreshBalance()` calls `GET /auth/me`, updates `gems` in state. Called from `ProfileBottomSheet` on open.
4. **Token injection**: `ApiService._headers` getter adds `Authorization: Bearer $token` if `ApiService.token != null`. All static methods use this.
5. **Logout**: removes all SharedPreferences keys, sets `ApiService.token = null`, resets `AuthState`.

---

## Error Handling

- **`ApiException`**: thrown by `ApiService._parse()` when `statusCode >= 400`. Contains `message` (from `detail` or `message` field) and `statusCode`.
- **Providers**: Riverpod `AsyncValue.error` state → screens show shimmer placeholders or empty states. No crash.
- **`fixUrl`**: returns `null` on null/empty input. Model fields are nullable `String?` — widgets check `isNotEmpty` before use.
- **`gemPackagesProvider`**: catches all exceptions and returns hardcoded fallback packages.
- **`pricingProvider`**: catches all exceptions and returns `const PricingModel()` with default multipliers.
- **`initCachedVideoController`**: double-catch pattern — if cache download or file init fails, retries with direct network URL. Returns `null` only if both fail.
- **Job polling**: `pollJobStatus` timer silently ignores transient HTTP errors and continues polling.

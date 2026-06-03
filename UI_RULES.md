# HypeCut — UI Rules & Design System

## Colors (`AppColors`)

> **Rule: ALL colors must use `AppColors.*` constants. Never use raw hex or `Color(0x...)` directly in widgets.**

| Constant | Hex | Usage |
|---|---|---|
| `backgroundPrimary` | `#0D0D0D` | Main scaffold background, `AppTheme.dark` scaffold color |
| `backgroundSecondary` | `#12121A` | Bottom sheets, modals |
| `backgroundCard` | `#1A1A2E` | Cards, toggles, inner containers |
| `accentPurple` | `#7B3FE4` | Secondary accent, icon tints, selected states |
| `accentPurpleLight` | `#8B47F5` | Primary CTA background, active nav, button borders |
| `accentPurpleDark` | `#5B2DB8` | Hover/pressed states |
| `svipGold` | `#FFB800` | SVIP label color |
| `svipGoldDark` | `#FF8C00` | SVIP secondary accent |
| `playsYellow` | `#FFB800` | Plays counter icon and text |
| `playsOrange` | `#FF6B00` | Plays gradient end (unused in current cards) |
| `playsRose` | `#BA9182` | Featured plays counter gradient start |
| `playsLemon` | `#EDD94C` | Featured plays counter gradient end |
| `textPrimary` | `#FFFFFF` | All primary text, card titles, prices |
| `textSecondary` | `#9E9E9E` | Subtitles, billing info, descriptions |
| `textHint` | `#616161` | Footer links, placeholder text, inactive labels |
| `gemBlue` | `#2196F3` | Gem icon tint |
| `bottomNavBackground` | `#1A1A28` | Bottom navigation bar fill |
| `bottomNavActive` | `#8B47F5` | Active nav icon and label |
| `bottomNavInactive` | `#616161` | Inactive nav icon and label |

---

## Gradients

### From `AppGradients` (`lib/core/theme/app_gradients.dart`)

| Name | Colors | Direction | Usage |
|---|---|---|---|
| `AppGradients.primaryButton` | `#8B47F5 → #8B47F5` (solid) | left→right | `GradientButton` CTA |
| `AppGradients.svipBadge` | `#7B3FE4 → #9B59F5` | left→right | `SvipBadge` widget |
| `AppGradients.cardOverlay` | `transparent → black` | top→bottom | Bottom overlay on all `TemplateCard` |
| `AppGradients.backgroundPurple` | `#4D7B3FE4 → transparent` (radial) | radial, center, r=0.8 | Onboarding background glow |

### From `PaywallScreen` (`lib/features/paywall/paywall_screen.dart`)

| Name | Colors | Direction | Usage |
|---|---|---|---|
| `_vipGradient` | `#BC5EF3 → #6834ED` | left→right | VIP tier: card borders, toggle tab, CTA button, card overlay |
| `_svipGradient` | `#FFAB9D → #FEFA19` | left→right | SVIP tier: same roles as above |
| `_vipBadgeGradient` | `#F89EFF → #A2D2FD` | left→right | "🏷 50% OFF" badge on the Yearly VIP card only |

---

## Typography

- **Font**: Google Fonts **Inter** throughout the entire app — never use the default Flutter `TextStyle` without specifying Inter.
- **Load pattern**: `GoogleFonts.inter(fontSize: ..., fontWeight: ..., color: ...)` inline, or via `AppTextStyles.*` getters for shared styles.
- **Never** use `Theme.of(context).textTheme.*` for custom text — it applies the Inter base but can't express all variants.

### `AppTextStyles` reference

| Getter | Size | Weight | Color |
|---|---|---|---|
| `heroTitle` | 36 | w900 | `accentPurple` |
| `heroSubtitle` | 36 | w900 | `textPrimary` |
| `sectionTitle` | 28 | w800 | `textPrimary` |
| `bodyLarge` | 16 | w400 | `textPrimary` |
| `bodyMedium` | 14 | w400 | `textSecondary` |
| `buttonText` | 18 | w700 | `textPrimary` |
| `cardTitle` | 15 | w700 | `textPrimary` |
| `playsText` | 13 | w600 | `playsYellow` |
| `badgeText` | 13 | w700 | `textPrimary` |
| `captionText` | 11 | w400 | `textSecondary` |

### Text hierarchy rule
- Titles / prices: **bold / w700–w900**
- Labels / badges: **w600**
- Body / billing info: **w400**

---

## Spacing (`AppSpacing`)

| Constant | Value | Usage |
|---|---|---|
| `xs` | 4 | Icon-to-text gap, tight spacing |
| `sm` | 8 | Small internal padding |
| `md` | 16 | Standard screen horizontal padding |
| `lg` | 24 | Section horizontal padding |
| `xl` | 32 | Large section gap |
| `xxl` | 48 | Extra-large vertical spacing |
| `cardPadding` | 12 | Internal card padding |
| `screenPadding` | 16 | Default horizontal screen padding |
| `sectionGap` | 24 | Gap between home sections |

---

## Border Radius (`AppRadius`)

| Constant | Value | Usage |
|---|---|---|
| `sm` | 8 | Small chips, small containers |
| `md` | 12 | Bonus block, inner containers |
| `lg` | 16 | `CustomButton`, standard cards |
| `xl` | 20 | Badges, `SvipBadge`, `TemplateCard` |
| `pill` | 30 | Toggle container, VIP/SVIP toggle |
| `circle` | 100 | Circular icon containers |

### Notable overrides (inline values, not from AppRadius)
- Paywall plan card outer: `24`
- Paywall plan card inner: `22`
- Paywall CTA button: `32`
- Featured carousel cards: `28`
- Bottom nav bar: `topLeft: 28, topRight: 28`

---

## Navigation Rules

```dart
context.pop()   // go back one screen
context.go()    // replace the entire navigation stack (root navigation)
context.push()  // push onto the stack (back button returns to previous screen)
```

### Navigation conventions
| Action | Method | Example |
|---|---|---|
| Close paywall → home | `context.go('/home')` | Close button in PaywallScreen |
| Open paywall from anywhere | `context.push('/paywall')` | ProfileBottomSheet upgrade button |
| Open template detail | `context.push('/home/template/$id')` | Card tap in HomeScreen |
| Open category | `context.push('/home/category/$name?id=$id&trending=$bool')` | Section header tap |
| Open swipe view | `context.push('/template-swipe?trending=true&index=$i')` | Featured carousel tap |
| Navigate to history | `context.go('/history')` | Bottom nav index 1 |
| Navigate to home | `context.go('/home')` | Bottom nav index 0 |

---

## Do Not Touch

These files must **never** be modified without explicit instruction:

- `lib/features/onboarding/onboarding_screen.dart`
- `lib/shared/widgets/scrolling_gif_grid.dart`
- `lib/shared/widgets/local_background_video.dart`

`lib/features/paywall/paywall_screen.dart` — **logic must not change** (pricing, tier toggle, navigation). UI/visual fixes are allowed.

---

## Shimmer Pattern

Always use `ShimmerPlaceholder` (from `template_card.dart`) for loading states. Never show empty space while data loads.

```dart
// Usage inside CachedNetworkImage
placeholder: (_, __) => const ShimmerPlaceholder(),

// Usage as standalone block
const ShimmerPlaceholder()
```

- `_ShimmerFeatured` — height 252, used in HomeScreen featured carousel
- `_ShimmerRow` — height 200, used in HomeScreen category rows
- `CachedNetworkImage` `placeholder` — on every thumbnail, detail screen, and swipe screen

---

## Card Layers Pattern

All template card widgets follow this Z-order in a `Stack`:

| Layer | Widget | Condition |
|---|---|---|
| 1 | `CachedNetworkImage(thumbUrl)` with `ShimmerPlaceholder` | Always |
| 2 | `AnimatedOpacity` → `Image.network(gifUrl)` or GIF layer | Center/active card only |
| 3 | `RepaintBoundary` → `FittedBox` → `VideoPlayer` | When controller initialized and card is first/active |
| 4 | `DecoratedBox(gradient: AppGradients.cardOverlay)` | Always |
| 5 | Text labels (title, `PlaysCounter`) | Always |

`RepaintBoundary` must wrap the video layer and the GIF layer to isolate repaints.

`AnimatedOpacity` must always be present (opacity 0 or 1) rather than conditionally inserted — this ensures the fade-out animation plays when toggling off.

---

## Quality Rules

- `flutter analyze` must return **0 issues** before any commit. Run: `flutter analyze ~/Desktop/hyper_cut`
- Run on device: `flutter run -d R5CY23GXQ2D` (Samsung Galaxy S24 FE)
- **No `print()`** — use `debugPrint()` only
- `withOpacity()` must be called on a `Color` value, not on a `Widget`
- All gradients on `ShaderMask` must pass `Rect bounds` from the callback: `shaderCallback: (bounds) => gradient.createShader(bounds)`
- `Clip.none` required on `Stack` when children overflow (e.g., floating badge above card top edge)
- `SingleChildScrollView(physics: NeverScrollableScrollPhysics())` + `ConstrainedBox(minHeight: screenH)` pattern used in PaywallScreen to prevent layout overflow without introducing a visible scrollbar

# HypeCut — Claude Code Instructions

> This file is read automatically by Claude Code at the start of every session.
> Do NOT modify without explicit instruction.

---

## Project Context

**HypeCut** is a Flutter app (dark theme, portrait only) for AI-powered short-form video generation.
Key docs live in the project root — always read them before making changes:

- `PROJECT.md` — tech stack, structure, known issues
- `ARCHITECTURE.md` — providers, data flow, models
- `UI_RULES.md` — colors, spacing, typography, gradients, do-not-touch files

**Run target**: `flutter run -d R5CY23GXQ2D` (Samsung Galaxy S24 FE)
**Analyze**: `flutter analyze` — must return 0 issues before every commit.

---

## Screen Implementation Workflow

When asked to implement a screen from reference screenshots, follow this exact loop:

### Step 1 — Study the screenshots
```
ls screenshots/          # list all reference images for the target screen
```
- Open every screenshot in the folder for that screen
- Extract: colors (use AppColors.* — never raw hex), spacing, font sizes, font weights,
  border radii, gradient directions, component Z-order, padding, alignment

### Step 2 — Cross-reference design system
Before writing a single line, re-read `UI_RULES.md` and confirm:
- Every color maps to an `AppColors.*` constant
- Every spacing value maps to `AppSpacing.*` or an approved inline override
- Every radius maps to `AppRadius.*` or an approved inline override
- Font is always `GoogleFonts.inter(...)` — never default TextStyle

### Step 3 — Implement the screen
- Follow the Card Layers Pattern from `UI_RULES.md` for any template card
- Use `ShimmerPlaceholder` for all loading states — never show empty space
- Use `RepaintBoundary` around video and GIF layers
- Use `AnimatedOpacity` (not conditional insert) for GIF toggle
- No `print()` — use `debugPrint()` only
- No raw `Color(0x...)` or hex strings in widget code

### Step 4 — Analyze
```bash
flutter analyze ~/Desktop/hyper_cut
```
Fix every issue before proceeding. Zero issues required.

### Step 5 — Visual verification loop

```bash
# Launch on Chrome for fast screenshot comparison
flutter run -d chrome --web-renderer html &
sleep 15
# Take a screenshot of the running app
# (use screencapture on macOS or scrot on Linux)
screencapture -x /tmp/current_screen.png
# OR on Linux:
# scrot /tmp/current_screen.png
```

Then compare `/tmp/current_screen.png` against the reference screenshot:
- Check overall layout and proportions
- Check colors match AppColors constants
- Check spacing consistency
- Check typography (size, weight, color)
- Check gradients and overlays

**Similarity threshold: 90%**

If similarity < 90%, identify the top differences, fix them, and repeat from Step 4.
Keep iterating until similarity ≥ 90%.

---

## Reference Screenshots Convention

Store screenshots in:
```
screenshots/
  <screen_name>/
    01_main.png
    02_detail.png
    03_state_x.png
    ...
```

Example:
```
screenshots/
  profile/
    01_main.png
    02_edit_mode.png
  gem_store/
    01_packages.png
```

When told "implement `GemStoreScreen` from screenshots", look in `screenshots/gem_store/`.

---

## Design System Quick Reference

### Colors (always use AppColors.*)
| Use case | Constant |
|---|---|
| Main background | `AppColors.backgroundPrimary` (`#0D0D0D`) |
| Bottom sheets / modals | `AppColors.backgroundSecondary` (`#12121A`) |
| Cards / containers | `AppColors.backgroundCard` (`#1A1A2E`) |
| Primary CTA, active nav | `AppColors.accentPurpleLight` (`#8B47F5`) |
| Secondary accent | `AppColors.accentPurple` (`#7B3FE4`) |
| Primary text | `AppColors.textPrimary` (`#FFFFFF`) |
| Subtitles / descriptions | `AppColors.textSecondary` (`#9E9E9E`) |
| Hints / inactive | `AppColors.textHint` (`#616161`) |
| Gem icon | `AppColors.gemBlue` (`#2196F3`) |
| SVIP label | `AppColors.svipGold` (`#FFB800`) |

### Spacing (AppSpacing.*)
`xs=4` · `sm=8` · `md=16` · `lg=24` · `xl=32` · `xxl=48`
`cardPadding=12` · `screenPadding=16` · `sectionGap=24`

### Radii (AppRadius.*)
`sm=8` · `md=12` · `lg=16` · `xl=20` · `pill=30` · `circle=100`

### Navigation
```dart
context.pop()   // back
context.go()    // replace stack
context.push()  // push (back button works)
```

### Gradients
```dart
AppGradients.primaryButton   // CTA buttons
AppGradients.svipBadge       // SVIP badge
AppGradients.cardOverlay     // bottom overlay on template cards
AppGradients.backgroundPurple // onboarding background glow
```

---

## Do Not Touch
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/shared/widgets/scrolling_gif_grid.dart`
- `lib/shared/widgets/local_background_video.dart`
- `lib/features/paywall/paywall_screen.dart` — logic only; UI fixes are OK

---

## Quality Gates (run before every commit)
```bash
flutter analyze ~/Desktop/hyper_cut   # must be 0 issues
flutter run -d R5CY23GXQ2D            # smoke test on device
```

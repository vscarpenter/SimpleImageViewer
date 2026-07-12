# Handoff: StillView "Studio" Redesign (direction 1c)

## Overview

A redesign of StillView's viewer window into a **pro inspector workspace**: one native unified toolbar, a segmented Single / Strip / Grid view-mode control, a docked bottom filmstrip, and a docked right inspector with Info and Insights tabs. It replaces today's floating bubble toolbar, stacked overlay panels, and modal grid.

It was chosen from a design review of the actual SwiftUI codebase; the findings it resolves (referenced below as V*/U*) come from the companion audit:

- **V1** every toolbar icon wore its own glass bubble → one flat toolbar, grouped by task
- **V2** photos sat on `windowBackgroundColor` → dedicated darker stage color
- **V4** toggle state was a 14 px glyph-fill swap → segmented control + filled tabs
- **V5** index badges on every thumbnail → no badges anywhere; selection ring only
- **U3** five independent panel booleans could stack → one view mode + one inspector
- **U4** Insights toggle reflowed the photo by 360 px → inspector is docked; stage size only changes when the inspector opens/closes as one animated move
- **U5** metadata couldn't be selected/copied → inspector text is selectable, rows copyable
- **U6** zoom was 5 buttons + a hidden preset-cycling chip → one zoom pill with a preset menu
- **U9** Esc was overloaded → Esc steps out one level (grid → single); only Back leaves the folder
- **U10** grid had no density/sort control → slider + sort menu in the toolbar

## About the Design Files

The files in this bundle are **design references created in HTML** — they show intended look and behavior; they are not production code. The task is to **recreate these designs in the existing StillView SwiftUI codebase** (macOS app, MVVM, Combine), using its established patterns. Do not port the HTML/CSS literally; translate it into SwiftUI views, system materials, and SF Symbols.

## Fidelity

**High-fidelity.** Colors, typography, spacing, and layout in the reference are intentional and should be matched closely (exact values below). Two deliberate exceptions:

1. **Icons** in the HTML are hand-drawn approximations — use the real SF Symbols listed in the Components section.
2. **Photos** are procedural placeholders — any real image library works for testing.

## Screens / Views

All three screens are states of **one window**. Reference window: 1180 × 740 pt. Layout regions:

```
┌──────────────────────────────────────────────┬───────────┐
│ Unified toolbar (52 pt)                       │           │
├──────────────────────────────────────────────┤ Inspector │
│                                              │ (300 pt)  │
│ Stage (fills)                                │           │
│                                              │           │
├──────────────────────────────────────────────┤           │
│ Filmstrip (78 pt)  — hidden in Grid mode     │           │
└──────────────────────────────────────────────┴───────────┘
```

### Screen 1 — Single view, Info inspector (dark) · `screenshots/01-studio.png`

**Purpose:** default browsing state; user reviews one photo with metadata alongside.

**Unified toolbar** (height 52, horizontal padding 16, item gap 14):
- Traffic lights (standard), then breadcrumb group: folder SF Symbol `folder` 15 pt secondary; folder name ("Landscapes") 13 pt semibold primary with 9 pt `chevron.down` — this is a **menu** (recent folders + "Choose Folder…"); counter "7 of 48" 12 pt monospaced digits, secondary.
- **Centered** segmented view-mode control: container corner radius 7, padding 2, background `white 7%` (dark) / `black 5.5%` (light); 3 segments height 26, padding 0 12, radius 5, icon 13 pt + label 12 pt medium. Active segment: `#57575B` bg, white text, shadow 0 1 2 black 30% (dark) / white bg, `#1D1D1F` text, shadow 0 1 3 black 14% (light). Inactive label: 60% / 55% foreground. Segments: `photo` Single · `rectangle.grid.1x2` Strip · `square.grid.3x3` Grid.
- Right group (flat 16 pt glyphs, gap 14, no button chrome): `play.circle` slideshow, `square.and.arrow.up` share, `trash` delete · 1×22 divider · **zoom pill**: height 26, padding 0 10, radius 6, bg `white 7%`/`black 5.5%`; contents `minus.magnifyingglass` 14 pt, "100%" 11.5 pt mono tabular + 8 pt chevron (opens preset menu: Fit, 50%, 100%, 200%, Actual Size), `plus.magnifyingglass` 14 pt · divider · `sidebar.right` 17 pt, **accent-tinted when inspector open**.

**Stage:** background `#161618` (dark). Image aspect-fit, inset ≥ 28 pt sides / 24 pt top-bottom. Hover prev/next arrows: 36 pt circles, bg `rgba(20,20,22,0.7)`, hairline `white 10%`, `chevron.left/right` 15 pt at 80% white; far-side arrow idles at 35% opacity.

**Filmstrip** (height 78, padding 0 14, item gap 8): thumbnails 84 × 56, `object-fit` fill-crop, radius 4. Non-selected at 65% opacity; hover 100%. Selected: 2 pt accent ring with 2 pt offset, full opacity. **No index badges.** Bar bg = toolbar bg; 1 px top hairline.

**Inspector** (width 300, left hairline; bg `#252527` dark / `#EFEEEC` light):
- Tab bar (padding 12 16 0): two equal pills, 12 pt; active = semibold on `white 10%` (dark) / `black 7%` (light), radius 6, padding 6 vertical.
- Content (padding 16, section gap 18):
  - Filename 13 pt semibold; meta line 11 pt secondary "5120 × 3200 · 3.0 MB · JPEG".
  - **Exposure spec strip**: 4-column grid, gap 6; tiles bg `white 5.5%`/`black 5%`, radius 6, padding 8 4, centered; value 12.5 pt semibold tabular ("ƒ/11", "1/60", "64", "16mm"), label 8.5 pt semibold letter-spacing 0.08em secondary (APERTURE / SHUTTER / ISO / FOCAL).
  - Sections CAMERA, DATES, LOCATION: header 10 pt semibold letter-spacing 0.1em secondary; key–value grid, key column 64 pt secondary, value 12 pt primary, row gap 6.
  - Footer (pinned bottom, top hairline): `doc.on.doc` 12 pt + "Values are selectable · click a row to copy" 10.5 pt secondary.

### Screen 2 — Single view, Insights inspector (light) · `screenshots/02-studio.png`

Same chrome in light theme. Insights tab active:
- Attribution row: `sparkles` 14 pt (warm tint `#B8730F`) + "Apple Intelligence · on-device" 10.5 pt secondary.
- Result title 14 pt semibold (−0.01em); summary 12 pt secondary, line-height 1.55.
- LIKELY CONTENT section (same section-header style), body 12 pt.
- TAGS: capsules 11 pt medium, bg `black 6%`, padding 4 9, radius full.
- LIMITATIONS caption 11 pt at 50%.
- Pinned bottom: **Regenerate Insight** filled accent button, height 32, radius 7, white 12.5 pt medium text with 13 pt `sparkles`. (Idle state: same button reads "Generate Insight"; generating state: spinner + Cancel, as in the current app.)
- Photos on the light stage get a cast shadow: `0 18 50 rgba(60,70,90,0.35)` + `0 3 12 rgba(0,0,0,0.12)`.

### Screen 3 — Grid mode with inspector (light) · `screenshots/03-studio.png`

- Segmented control: Grid active. Toolbar right group swaps zoom pill for: **density slider** (track 84 × 3, radius 2, knob 13 pt circle w/ hairline+shadow, small/large `photo` glyphs at 11/15 pt) · divider · sort menu "Name" 12 pt + chevron (Name, Date Captured, Date Modified, Size) · divider · `sidebar.right`.
- Grid pane replaces stage + filmstrip: padding 16, 5-column grid (adaptive ≈ 160 pt min), gap 10; tiles fill-crop, height ≈ 118 at reference size, radius 6. **No badges, no captions.** Hover: filename tooltip / subtle ring. Selected: 3 pt accent ring inset + 18 pt `checkmark.circle.fill` accent badge top-right (6 pt inset).
- Inspector persists and follows selection; Info tab adds a 150 pt-tall rounded (8) preview image above the filename block.
- Return/double-click opens selection in Single; Esc returns to Single (not to folder selection).

## Interactions & Behavior

- **View modes:** one mutually-exclusive mode: `single | strip | grid`. Keyboard: T → Strip, G → Grid (toggle back to Single), existing arrow/Home/End/Space navigation unchanged. Strip mode = Single + filmstrip visible (filmstrip is shown in Single too by default; Strip forces it, Grid hides it — if you prefer, treat filmstrip visibility as part of the mode exactly as in the mocks).
- **Inspector:** I toggles inspector (opens to Info); Cmd+I opens Insights. Open/close animates the stage width as a single ease (~0.3 s, respect Reduce Motion). Tab switch never reflows the stage.
- **Zoom:** pill menu presets; double-click stage toggles Fit ↔ 100%; pinch/scroll zoom unchanged. Percentage always tabular digits.
- **Hover chrome:** prev/next arrows fade in on pointer movement over the stage, fade out after ~3 s idle (existing auto-hide timer logic can be reused).
- **Esc ladder:** grid → single; sheet/menu → dismiss; never exits to folder selection (Back/breadcrumb does that). Update `KeyboardHandler` accordingly.
- **Delete:** moves to Trash with an undo toast (existing behavior), glyph sits in toolbar right group.
- **Slideshow:** `play.circle` starts; while active the glyph becomes `pause.circle.fill` accent-tinted; click-and-hold or right-click reveals interval popover (2/5/10 s).
- **Filmstrip:** click jumps; auto-scrolls selection to center (existing `ScrollViewReader` logic); right-click keeps the existing thumbnail context menu.

## State Management

Replace the current independent booleans on `ImageViewerViewModel` (`showImageInfo`, `showAIInsights`, `viewMode`, strip/grid toggles) with:

```swift
enum ViewMode { case single, strip, grid }        // one source of truth
enum InspectorTab { case info, insights }
@Published var viewMode: ViewMode = .single
@Published var inspectorVisible: Bool
@Published var inspectorTab: InspectorTab = .info
// existing: currentIndex, zoomLevel (fit sentinel), isSlideshow, slideshowInterval
```

Insights generation states (idle / generating / result / failed / unavailable) already exist in `ImageInsightViewModel` — reuse them; only the presentation moves into the inspector tab.

## Design Tokens

| Token | Dark | Light |
|---|---|---|
| Stage (canvas behind photo) | `#161618` | `#DEDCD6` |
| Chrome (toolbar, filmstrip) | `#2B2B2D` | `#F4F3F1` |
| Inspector background | `#252527` | `#EFEEEC` |
| Hairline separators | `rgba(0,0,0,0.55)` | `rgba(0,0,0,0.10–0.12)` |
| Primary text | `rgba(255,255,255,0.90)` | `#1D1D1F` |
| Secondary text | `#8E8E93` | `rgba(0,0,0,0.45–0.55)` |
| Accent (selection, active) | `#0A84FF` (system) | `#007AFF` (system) |
| Segmented container | `rgba(255,255,255,0.07)` | `rgba(0,0,0,0.055)` |
| Segmented active thumb | `#57575B` | `#FFFFFF` |
| Stat tile / pill fill | `rgba(255,255,255,0.055–0.07)` | `rgba(0,0,0,0.05–0.055)` |
| Sparkles/AI tint | system accent or `#B8730F` warm | `#B8730F` |

Prefer semantic NSColor equivalents where they match (`controlAccentColor` for accent, `labelColor`/`secondaryLabelColor` for text); use the literal stage/chrome values above rather than `windowBackgroundColor` — the dedicated stage color is the point (finding V2). Add them to `Color+Adaptive.swift` as e.g. `appStage`, `appChrome`, `appInspector`.

**Type scale:** 13 semibold (titles/filenames) · 12 medium (controls) · 12 regular (values) · 11 (metadata) · 10 semibold +0.1em uppercase (section headers) · 8.5 semibold +0.08em (tile labels). Counters/zoom always `.monospacedDigit()`.

**Radii:** 4 (filmstrip thumbs) · 5–7 (segments, pills, tiles) · 6 (grid tiles) · 8 (inspector preview). **Spacing:** 6/8/10/14/16/18 as specified per component.

## Suggested file mapping (existing codebase)

- `Views/NavigationControlsView.swift` + `ToolbarButtonStyles.swift` + `ToolbarOverflowMenu.swift` → replaced by a `StudioToolbar` view (bubble button styles deleted; overflow no longer needed at this control count)
- `ContentView.swift` `ThumbnailStripView` → docked `FilmstripView` (drop index capsules, material card)
- `ContentView.swift` `ThumbnailGridView` (full-screen overlay) → `GridPane` swapped into the stage region
- `Views/ImageInfoOverlayView.swift` → `InspectorView` Info tab (make text selectable; remove `allowsHitTesting(false)`)
- `Views/ImageInsightPanelView.swift` → `InspectorView` Insights tab (content largely reusable)
- `Services/KeyboardHandler.swift` → Esc ladder + mode keys per Interactions
- `Extensions/Color+Adaptive.swift` → new stage/chrome/inspector tokens

## Assets

- `photos/` — 12 procedural placeholder images (generated for the mockups; not for production).
- Icons — SF Symbols only: `folder`, `chevron.down`, `chevron.left/right`, `photo`, `rectangle.grid.1x2`, `square.grid.3x3`, `play.circle`, `pause.circle.fill`, `square.and.arrow.up`, `trash`, `minus.magnifyingglass`, `plus.magnifyingglass`, `sidebar.right`, `sparkles`, `checkmark.circle.fill`, `doc.on.doc`.
- No custom fonts: SF Pro (system) + monospaced digits.

## Files

- `studio-design-reference.html` — the three screens, self-contained (open in any browser; frames render at 70% scale)
- `screenshots/01-studio.png` — dark · Single view + Info inspector
- `screenshots/02-studio.png` — light · Single view + Insights inspector
- `screenshots/03-studio.png` — light · Grid mode + inspector
- `photos/` — placeholder images the reference HTML loads

# Settings redesign — 2026-09-06

Design direction: native macOS product UI, restrained system colors, low layout variance (2/10). The distinctive detail is a compact toolbar window whose height and title follow the selected pane.

## Composition
- General: launch display switches and precise slideshow duration stepper, with timing and repeat behavior explained.
- Intelligence: analysis and enhancement switches, concise capability and original-file explanations, and the published Privacy Policy link.
- Shortcuts: native search field above a scrolling, plain list reference generated from the active keyboard handler; clear search and empty results use system behavior.
- Settings… in the App menu opens with Command–Comma. Help → Keyboard Shortcuts opens that pane directly.
- The Appearance pane is retired; Settings follows the Mac's appearance and accessibility options. A stored appearance pane safely opens General.

## Implementation plan
1. Replace custom tabs, cards, focus handlers, and window materials with AppKit's native preference toolbar and SwiftUI forms.
2. Preserve one shared preferences model, startup/live semantics, and remembered pane selection.
3. Update user-facing Help and release copy for the new navigation.
4. Build, run lifecycle regressions and the existing suite, then inspect real controls, search, focus, and both appearances.

## Acceptance
- All General and Intelligence content fits without scrolling at normal system text size.
- Native toolbar shows the active pane, remains fixed, and uses disabled minimize/zoom controls.
- Switches, stepper, and search expose meaningful accessible names and visible keyboard focus.
- Selection is synchronized in both directions without reentrant published updates.
- Search handles matches, no results, clearing, and whitespace.
- Closing/reopening restores the selected pane; Help routing works from another pane.
- No changes to original image files, processing semantics, or preference keys beyond pane selection.

## Reference
[Apple Human Interface Guidelines: Settings](https://developer.apple.com/design/human-interface-guidelines/settings)

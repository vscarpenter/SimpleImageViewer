# StillView 4.3.0 marketing screenshots

Captured July 11, 2026 from the 4.3.0 (33) build on macOS 26.5, using the studio redesign UI. Every shot shows the real app browsing a 14-photo demo folder named "Landscapes" with injected EXIF, GPS, and IPTC keywords, so the Info and Insights panels display full data.

## appstore/

Seven opaque PNGs at exactly 1440×900 (an accepted Mac App Store size, 16:10). Upload in numbered order.

App Store Connect has no caption field for Mac screenshots. Bake these into the artwork or reuse them on the site.

| File | Shows | Headline | Supporting line |
|---|---|---|---|
| 01-hero | Single view, dark, Isle of Skye photo | A calmer way to view your photos | Point StillView at a folder and look. No library, no import, no clutter. |
| 02-ai-insights | Insights panel with on-device result | AI Insights, entirely on your Mac | Apple Intelligence describes what the photo shows. Nothing leaves your device. |
| 03-grid | Grid mode with Info inspector | The whole folder at a glance | Grid view with a density slider and sorting, details one click away. |
| 04-navigation | Strip mode, filmstrip, hover arrows | Built for the keyboard | Arrow keys, a filmstrip, and one-key view modes keep browsing quick. |
| 05-info | Info inspector with EXIF and GPS | Every detail, one panel away | Camera, exposure, dates, and location. Click any row to copy it. |
| 06-zoom | 100% zoom on city detail | Zoom to the pixel | Fit to window or jump to actual size with a single key. |
| 07-immersive | Strip mode, fjord photo | Your photos, front and center | A quiet, dark stage keeps the interface out of the way. |

## appstore-captioned/

The same seven shots with the captions baked in: gradient backdrop, headline, supporting line, and the window at 78% with a cast shadow. Same 1440×900 opaque PNGs, same upload order. Pick one set per listing; mixing captioned and clean frames reads as inconsistent. `scripts/caption_bake.swift` regenerates this set from the raw captures.

## website/

WebP pairs sized for the "See It in Action" gallery on stillviewapp.com: 1240×775 large, 440×275 thumb. `stillview-ai-insights-*.webp` matches the existing filenames, so it replaces the current pair directly. The rest use new `stillview43-*` names. Update the six `thumb-card` blocks in index.html to point at the new files and adjust the thumb `height` attributes from 267 to 275.

Slot mapping: Clean Interface → hero, Gallery Mode → grid, Full Screen View → immersive, Easy Navigation → navigation, Zoom & Detail → zoom, AI Insights → ai-insights.

## sample-photos/

The 14 demo photos (source: picsum.photos, which serves Unsplash-licensed images; free for commercial use). Each carries realistic EXIF, a few carry GPS and IPTC keywords. Open this folder in StillView to re-create any shot.

## scripts/

- `prep_photos.swift` rebuilds the demo photo set from picsum.photos with the same EXIF injection.
- `finalize.swift` flattens raw captures into App Store PNGs and website sizes.
- `window-snapshot-rig.patch` adds the Debug-only capture menu to `SimpleImageViewerApp.swift` (a "Save Window Snapshot" item that captures the app's own window through the window server, plus a "Set Window 1440×900" item). Apply with `git apply`, build Debug, and drive the app with System Events. The patch never ships: everything sits behind `#if DEBUG`.

## Re-shoot recipe

1. `git apply scripts/window-snapshot-rig.patch`, then build the Debug scheme.
2. Launch, open the sample-photos folder, and set the window via Debug → Set Window 1440×900.
3. Stage each state with the normal shortcuts (T strip, G grid, I inspector, ⌘I Insights, 0/1 zoom).
4. Debug → Save Window Snapshot writes PNGs to the app container's `tmp/snapshots/`.
5. Run `finalize.swift` to regenerate both output sets.

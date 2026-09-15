# StillView 5.0.0 marketing screenshots

Captured September 15, 2026 from the 5.0.0 (40) build on macOS 27.0 (26A428), on a Retina display. Every shot shows the real app browsing the 14-photo demo folder from `../screenshots-4.3.0/sample-photos/`, staged as a folder named "Landscapes", so the Info and Insights panels display full data. The Insights frame shows a real on-device result for the winter camp photo.

## appstore/

Eight opaque PNGs at exactly 2880×1800 (the largest accepted Mac App Store size, 16:10). Upload in numbered order. App Store Connect has no caption field for Mac screenshots, so the captions below are baked into the second set.

| File | Shows | Headline | Supporting line |
|---|---|---|---|
| 01-hero | Single view, dark, Isle of Skye road | A calmer way to view your photos | Point StillView at a folder and look. No library, no import, no clutter. |
| 02-ai-insights | Insights inspector with an on-device result, light | AI Insights, entirely on your Mac | Apple Intelligence describes the photo and reads its text. Nothing leaves your Mac. |
| 03-grid | Grid mode with the Info inspector, light | The whole folder at a glance | Grid view with a density slider and sorting, details one click away. |
| 04-navigation | Strip mode, filmstrip, hover arrows | Built for the keyboard | Arrow keys, a filmstrip, and one-key view modes keep browsing quick. |
| 05-info | Info inspector with EXIF and GPS | Every detail, one panel away | Camera, exposure, dates, and location. Click any row to copy it. |
| 06-zoom | 100% zoom on the city photo | Zoom to the pixel | Fit to window or jump to actual size with a single key. |
| 07-immersive | Strip mode, fjord photo | Your photos, front and center | A quiet, dark stage keeps the interface out of the way. |
| 08-settings | Settings, Shortcuts pane, "image" search, light | Settings that follow your Mac | Native General and Intelligence panes, plus a searchable shortcut reference. |

## appstore-captioned/

The same eight frames with captions baked in: gradient backdrop, headline, supporting line, and the window at 78% with a cast shadow. The Settings window draws at its captured size. Same 2880×1800 opaque PNGs, same upload order. Pick one set per listing.

## website/

WebP pairs for stillviewapp.com: 1240×775 large and 440×275 thumb, named `stillview50-*`. The landing page uses three of the large files (grid, info, ai-insights) in its feature rows. The rest are ready for the gallery if it returns.

## scripts/

- `window-snapshot-rig.patch` adds the Debug-only capture menu to `SimpleImageViewerApp.swift`: "Save Window Snapshot @2x" (⌥⌘S) captures the app's own window through the window server, and "Set Window 1440×900" sizes it. Apply with `git apply`, build Debug, and drive the app with System Events. The patch never ships; everything sits behind `#if DEBUG`. Regenerated from the 5.0.0 source, since the 4.3.0 patch no longer applied.
- `finalize.swift` flattens raw captures into App Store PNGs and stages website PNGs. ImageIO on macOS 27 cannot write WebP, so convert the staged PNGs with `cwebp -q 88` (Homebrew `webp`).
- `caption_bake.swift` composes the captioned set.

## Re-shoot recipe

1. `git apply marketing/screenshots-5.0.0/scripts/window-snapshot-rig.patch`, build the Debug scheme, and ad-hoc sign the app with its entitlements so it runs sandboxed.
2. Copy `../screenshots-4.3.0/sample-photos/` to a folder named `Landscapes` and open it. Set the window via Debug → Set Window 1440×900.
3. Stage each state with the normal shortcuts (T strip, G grid, I inspector, ⌘I Insights, 0 and 1 zoom, ⌘, Settings). Move the pointer off the window before saving unless the shot needs hover arrows.
4. Debug → Save Window Snapshot @2x writes PNGs to the app container's `tmp/snapshots/`. Capture the Settings window with `screencapture -o -l <windowID>`.
5. Run `swift finalize.swift <captures> <this folder> <png-staging>`, convert the staging PNGs with cwebp into `website/`, then run `swift caption_bake.swift <captures> appstore-captioned`.
6. Revert the patch before committing.

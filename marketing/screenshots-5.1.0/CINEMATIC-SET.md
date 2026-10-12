# StillView 5.1 — cinematic App Store screenshots

Created October 12, 2026 from StillView **5.1.0 (45)** on macOS **27.0.1 (26A434)**. This is the completed cinematic dark set. The earlier README capture plan is retained as reference.

Use the ten numbered PNGs in `appstore-cinematic/`, in order. Each export is **2880 × 1800**, 16:10, opaque, and sRGB. The contact sheet is a review aid, not an upload image. Apple lists this as an accepted Mac screenshot size and permits up to ten screenshots: [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

| Order | Feature | Actual app state |
|---|---|---|
| 01 | Your photos. Room to breathe. | Highland road, Single view, Fit, panels hidden |
| 02 | Every subfolder. One view. | All 15 images, Grid, expanded Coast/Fjords and Mountains/Winter tree, relative folder paths |
| 03 | AI Insights. On your Mac. | Winter camp, Single, real on-device description, 15 of 15 |
| 04 | Copy the words you see. | Fictional trailhead notice, AI Insights off, 16 recognized lines expanded, Copy text visible |
| 05 | Find your next favorite. | Full collection in Grid, canyon selected, thumbnail and sorting controls visible |
| 06 | Keep moving. Stay in the moment. | Lakeside dock, Strip, all 15 filmstrip thumbnails |
| 07 | The details behind the image. | Northern lights, Info inspector, demonstration camera/exposure/date/GPS metadata |
| 08 | Get closer. | Canyon sunset at actual size; 100% visible in the toolbar |
| 09 | A view worth lingering over. | Fjord overlook, Single, Fit, panels hidden |
| 10 | Make it feel like your Mac. | Actual native Settings window, Shortcuts, “image” search |

All interface pixels come from the running app. Descriptions and OCR are unedited outputs from this capture session. The compositions add only typography, a restrained photo-derived background tint, and a shadow matching the window alpha. They preserve complete window geometry with uniform scaling. No interface, controls, text results, ratings, or device frame were fabricated. This follows Apple's guidance to show the app in use: [accurate metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata).

## Files

- `exports/StillView-5.1-AppStore-Cinematic.zip`: the ten upload PNGs only.
- `exports/StillView-5.1-Screenshot-Source.zip`: portable editable source kit, clean captures, sample photos, copy JSON, renderer, credits, and capture helper patch.
- `appstore-cinematic/contact-sheet.png`: overview of the complete set.
- `appstore-cinematic/render-manifest.json`: source and export hashes, scale, crop, and composition data.
- `capture-session.json`: app/build provenance, native capture mapping, and preference restoration.
- `verification.json`: PNG dimensions, color profile, alpha, and hashes.
- `captures/`: the ten clean captures; `native/` preserves helper originals and `alternates/` retains the city zoom alternative.
- `cinematic-copy.json`: editable headlines, supporting lines, layout settings, and tint photo choices.
- `scripts/cinematic_bake.swift`: editable Swift/AppKit layout renderer.
- `PHOTO-CREDITS.md` and `asset-provenance.json`: photographer/source links, embedded Picsum IDs, local hashes, and the synthetic metadata disclosure.

## Re-render

From the repository root on a Mac with Xcode installed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  marketing/screenshots-5.1.0/scripts/cinematic_bake.swift \
  marketing/screenshots-5.1.0/captures \
  marketing/screenshots-5.1.0/appstore-cinematic \
  marketing/screenshots-4.3.0/sample-photos
```

The portable source ZIP uses the same command with `scripts/cinematic_bake.swift captures output photos`. Final mode rejects a missing capture. For copy iteration on a subset, add `--preview --shots hero,ai-insights` and use a separate preview output directory.

## Capture helper

The existing helper needed a macOS 27 capture update. `scripts/window-snapshot-macos27.patch` applies on top of the user's existing, uncommitted screenshot helper. It uses `SCShareableContent.currentProcess` and a single-window filter, so only StillView's own windows are captured. It also offers a sandbox-safe output-folder picker, handles leaving fullscreen before standard sizing, and captures the active Settings window. All changes are DEBUG-only. The original source file was restored after capturing; the patch is provided separately and was checked for clean application.

Build a temporary capture app with `ENABLE_DEBUG_DYLIB=NO` to avoid a launcher/debug-library signature mismatch when using an ad-hoc signed bundle. The capture session used the existing sandbox entitlements. An early temporary copy failed at launch due to mismatched signatures; it was disabled. The replacement completed the browsing, AI, OCR, Settings, and final capture flows with no subsequent StillView crash report observed.

After applying the patch in Debug, the Help menu exposes the helper controls: **Choose Snapshot Folder** (⌥⌘E), **Set Window 1440×900** (⌥⌘9), and **Save Window Snapshot @2x** (⌥⌘S). If starting in fullscreen, use standard sizing once to exit, then again to size the window. Choose an empty capture folder before saving. Main-window captures were verified as 2880 × 1800; the Settings capture was 1120 × 1056. The final composition scales that smaller native window for legibility.

Dark appearance was used only for the captures, then the original **Light** setting was restored. AI Insights was temporarily disabled for OCR, then restored to **on**. The photo library and original images were preserved. No App Store upload, commit, push, or website publication was performed.

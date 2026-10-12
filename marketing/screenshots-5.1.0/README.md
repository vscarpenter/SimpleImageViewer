# StillView 5.1.0 marketing screenshots

**Completed cinematic set — October 12, 2026:** ten fresh 2880 × 1800 opaque sRGB App Store screenshots are available in [`appstore-cinematic/`](appstore-cinematic/), with upload and editable-source ZIPs in [`exports/`](exports/). See [`CINEMATIC-SET.md`](CINEMATIC-SET.md) for the verified shot list, provenance, capture helper update, and re-render instructions. The plan below is retained as reference.

The capture plan for the 5.1.0 (45) listing. Frames still need capturing on a Mac running the 5.1 build; this folder holds the shot list, captions, demo library, and scripts. Shoot every frame fresh, because 5.1 changed the descriptions, toolbar labels, and Grid selection outline that older frames show.

## Shot list

Ten opaque PNGs at exactly 2880×1800, the largest accepted Mac App Store size (16:10). Ten is the per-listing maximum. The first three carry the listing, so the headline 5.1 feature sits in slot 2.

| # | Capture file | Shows | Headline | Supporting line |
|---|---|---|---|---|
| 01 | hero.png | Single view, dark, `Mountains/highland-road.jpg` | A calmer way to view your photos | Point StillView at a folder and look. No library, no import, no clutter. |
| 02 | subfolders.png | Grid, light, Include Subfolders on, folder tree open with `Mountains` expanded, relative-path captions visible | Every subfolder in one view | Include subfolders to see the whole tree, then filter by folder or search by name. |
| 03 | insights.png | Insights inspector, light, `Mountains/Winter/winter-camp.jpg` with a real on-device description | AI Insights, entirely on your Mac | Apple Intelligence describes the photo on this Mac. Nothing is uploaded. |
| 04 | text.png | Insights inspector, light, `Coast/Fjords/trailhead-notice.png` with Text in image expanded. Capture with AI Insights turned off in Settings so only Extract text shows. | Copy the text in any image | Extract text runs on your Mac, even with AI Insights turned off. |
| 05 | grid.png | Grid with the Info inspector, light, selection outline visible | The whole folder at a glance | Sort, resize thumbnails, and move by row with the arrow keys. |
| 06 | navigation.png | Strip mode, filmstrip, hover arrows, `Coast/lakeside-dock.jpg` | Built for the keyboard | Arrow keys, a filmstrip, and one-key view modes keep browsing quick. |
| 07 | info.png | Info inspector with EXIF and GPS, `Mountains/Winter/northern-lights.jpg` | Every detail, one panel away | Camera, exposure, dates, and location. Click any row to copy it. |
| 08 | zoom.png | 100% zoom, `Towns/city-from-above.jpg` | Zoom to the pixel | Fit to window or jump to actual size with a single key. |
| 09 | immersive.png | Strip mode, dark, `Coast/Fjords/fjord-overlook.jpg` | Your photos, front and center | A quiet, dark stage keeps the interface out of the way. |
| 10 | settings.png | Settings, Shortcuts pane, "image" search, light | Settings that follow your Mac | Native General and Intelligence panes, plus a searchable shortcut reference. |

The 03 supporting line changed from 5.0, which said Apple Intelligence "reads its text." Vision recognizes the text, and frame 04 now covers it.

## Demo library

`scripts/stage-demo-library.sh` copies the 14 photos from `../screenshots-4.3.0/sample-photos/` into a nested `~/Pictures/Landscapes` folder (Coast, Coast/Fjords, Forest, Mountains, Mountains/Winter, Towns, plus one photo at the root) and adds `sample-documents/trailhead-notice.png` for frame 04. It refuses to overwrite an existing folder. The notice is a rendered demo document, not a photo of a real sign.

## Capture steps

1. `git apply marketing/screenshots-5.1.0/scripts/window-snapshot-rig.patch`. It was regenerated against the 5.1 source because the 5.0 patch no longer applied. Build the Debug scheme and ad-hoc sign it with its entitlements so it runs sandboxed.
2. Run `marketing/screenshots-5.1.0/scripts/stage-demo-library.sh`, open `~/Pictures/Landscapes`, and choose Debug → Set Window 1440×900.
3. Stage each frame from the table. Move the pointer off the window unless the frame needs hover arrows. Debug → Save Window Snapshot @2x (⌥⌘S) writes `snap-NNN.png` files to the app container's `tmp/snapshots/`. Capture Settings with `screencapture -o -l <windowID>`.
4. Rename each capture to the file name in the table (`hero.png`, `subfolders.png`, and so on) in one folder.
5. Run `swift scripts/finalize.swift <captures> <this folder> <png-staging>` for the clean `appstore/` set and website PNGs, then `cwebp -q 88` on the staged PNGs into `website/` (named `stillview51-*`).
6. Run `swift scripts/caption_bake.swift <captures> appstore-captioned` for the captioned set.
7. Revert the patch before committing, and confirm with `git status` that `SimpleImageViewerApp.swift` is unchanged.
8. Upload one set, `appstore/` or `appstore-captioned/`, in numbered order.

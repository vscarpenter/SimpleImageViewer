# App Store Submission Package: StillView 5.0.0 (44)

Metadata for the macOS 27 release. The project identity below matches the current Xcode project. Verify the signed archive, App Store Connect fields, and public privacy page before submission; this document does not confirm upload or approval.

## Version and identity

| Field | Value |
|---|---|
| Bundle ID | `com.vinny.StillView-Image-Viewer` |
| App Name | StillView - Image Viewer |
| Marketing Version | 5.0.0 |
| Build Number | 44 |
| Primary Category | Photo & Video (secondary: Utilities) |
| Minimum macOS | 27.0 |

Build 44 must exceed the last build uploaded to App Store Connect. If another build number is needed, run `scripts/update-version.sh --bump-build` and rebuild.

## Metadata fields

### Subtitle

```
Distraction-free image viewer
```

### Promotional text

```
Apple Intelligence describes your photos and reads their text, entirely on your Mac. Browse any folder in Single, Strip, or Grid view. No account and no tracking.
```

### Description

```
StillView is a native macOS image viewer for browsing local folders of photos and screenshots. No account is required. Image viewing and analysis work on your Mac.

BROWSE YOUR IMAGES
Open a folder and move through its images with arrow keys. Zoom, inspect at actual size, or fit an image to the window. Use fullscreen for a closer look.

THREE VIEWING MODES
Single keeps your attention on one image. Strip adds a docked filmstrip for navigation. Grid displays thumbnails with density and sorting controls. The Info inspector shows file details, dimensions, color information, and available EXIF camera metadata.

SUPPORTED FORMATS
JPEG, PNG, GIF, HEIF/HEIC, WebP, TIFF, and BMP. Animated GIF and WebP display their first frame only; multipage TIFF displays its first image. SVG and PDF are not supported.

ON-DEVICE INSIGHTS
AI Insights gives Apple Intelligence the selected image to describe its visible content on your Mac. Read a concise description and notable details, copy the description, or expand original recognized text. Generated descriptions and OCR may contain errors. The app does not identify people.

Insights requires an Apple Intelligence eligible Mac, Apple Intelligence enabled in System Settings, and its on-device model ready. Enable Insights in the app, then choose Analyze image. Images, recognized text, metadata, and results stay on this Mac.

EVERYDAY CONTROLS
Start a slideshow with adjustable duration and automatic repeat. Share the current image through macOS sharing services, or confirm its name before moving it to Trash. The Shortcuts tab provides a searchable reference to built-in image commands.

PRIVACY AND PERMISSIONS
No data collection, analytics, or tracking. StillView uses App Sandbox and accesses folders you select. Read-write access supports moving a confirmed image to Trash. Optional display enhancements preserve the original file. Sharing and external website links open when you choose them.

Requires macOS 27 or later and Apple silicon. AI Insights additionally requires Apple Intelligence enabled and its on-device model ready.
```

### Keywords

```
photo,browser,folder,gallery,slideshow,JPEG,HEIC,WebP,thumbnail,EXIF,metadata,OCR,offline,privacy
```

The app name and subtitle already carry "image" and "viewer," and the Mac App Store implies macOS, so those words are left out of the 100-character limit.

### What’s New

```
StillView 5.0 requires macOS 27 and Apple silicon.

AI INSIGHTS, REBUILT
• Apple Intelligence now sees the image itself and describes the visible scene on your Mac.
• Results include notable visual details, suggested tags, and anything the model is unsure about.
• Text in image shows the original recognized text, keeps repeated lines, and says when it was cut short.
• Copy the description, refresh it, or cancel a run. A failed refresh keeps the previous result.

ALSO IN THIS RELEASE
• Inspector rows offer a VoiceOver Copy action.
• The welcome screen honors Reduce Motion.

Images, recognized text, and results stay on this Mac.
```

The Mac App Store shipped 4.6.0 (36) on September 6, 2026, with native Settings, the compact toolbar, and the folder, keyboard, Trash, zoom, and loading fixes, so this text covers only what changed after it.

### URLs

| Field | Value |
|---|---|
| Support URL | https://github.com/vscarpenter/SimpleImageViewer/issues |
| Marketing URL | https://stillviewapp.com/ |
| Privacy Policy URL | https://stillviewapp.com/privacy.html |
| Website Terms of Use | https://stillviewapp.com/terms.html |

Both pages returned HTTPS 200 on September 15, 2026, with a September 15 effective date and the Foundation Models description of AI Insights from `docs/reviews/2026-09-15-macos27-launch-readiness.md`. The privacy URL in App Store Connect matches. The website Terms URL is recorded for reference, not as confirmation of an App Store Connect EULA selection.

## App Privacy and review information

The app does not collect data, use analytics SDKs, or track users. Confirm that App Store Connect’s privacy answers match the signed binary and its `PrivacyInfo.xcprivacy` file. Local file access and required-reason API declarations are separate from data collection disclosures.

Complete the current age-rating questionnaire in App Store Connect using the actual product behavior: it displays user-selected local images and local analysis results, has no hosted content feed or account system, and does not generate images, audio, or video. Do not rely on a rating or questionnaire saved from an older release.

The project declares `ITSAppUsesNonExemptEncryption = NO`. Recheck the export-compliance answers for the submitted archive in App Store Connect.

## Screenshots and reviewer notes

Upload the 5.0.0 set from `marketing/screenshots-5.0.0/appstore-captioned/` (or the clean `appstore/` set, not both): eight 2880×1800 PNGs captured on September 15, 2026, covering Single, Insights with a real on-device result, Grid, Strip, Info, 100% zoom, and the Shortcuts reference. Both pages of `marketing/screenshots-5.0.0/README.md` list the order and captions.

Paste [AppStoreReviewNotes.md](AppStoreReviewNotes.md) into App Review Information → Notes. The app has no sign-in or demo credentials. Reviewers can use a local image folder.

## Pre-submission checks

- [x] Verify 5.0.0 (44), the bundle ID, and the macOS 27 deployment target against the selected archive and App Store Connect.
- [ ] Set `releaseDate` in `Resources/whats-new.json` to the submission date so the in-app What's New sheet shows the right day.
- [ ] Run the repository’s lint and tests, and confirm CI for the exact submission commit.
- [ ] Create a distribution archive in Xcode and validate it in Organizer.
- [ ] Inspect the signed app’s entitlements with `codesign -d --entitlements - "<App>.app"`: App Sandbox, user-selected read-write files, and app-scope bookmarks are expected; `get-task-allow` must be absent from the distribution app.
- [ ] Verify `PrivacyInfo.xcprivacy` and the app icon exist inside the archived app’s `Contents/Resources` directory.
- [x] Verify the privacy and terms pages are publicly reachable over HTTPS.
- [x] Publish the AI Insights policy-copy correction on both pages and recheck the privacy link from the distribution-signed app.
- [ ] Exercise opening/canceling a folder, viewer keyboard focus, Trash confirmation, narrow Grid layout, and all remaining preferences in the signed app.
- [ ] Exercise AI Insights on eligible hardware with the on-device model ready, plus its disabled/unavailable states.
- [x] Upload the archive through Xcode Organizer, wait for processing, and select that build in App Store Connect.
- [x] Review all metadata, privacy answers, age rating, screenshots, and reviewer notes before submission. Verified in App Store Connect on September 15, 2026; see `tasks/todo.md`.

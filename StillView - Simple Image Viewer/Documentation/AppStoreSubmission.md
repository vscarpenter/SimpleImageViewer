# App Store Submission Package: StillView 5.0.0 (40)

Metadata for the macOS 27 release. The project identity below matches the current Xcode project. Verify the signed archive, App Store Connect fields, and public privacy page before submission; this document does not confirm upload or approval.

## Version and identity

| Field | Value |
|---|---|
| Bundle ID | `com.vinny.StillView-Image-Viewer` |
| App Name | StillView - Image Viewer |
| Marketing Version | 5.0.0 |
| Build Number | 40 |
| Primary Category | Photography |
| Minimum macOS | 27.0 |

Build 40 must exceed the last build uploaded to App Store Connect. If another build number is needed, run `scripts/update-version.sh --bump-build` and rebuild.

## Metadata fields

### Subtitle

```
Distraction-free image viewer
```

### Promotional text

```
Browse photos in Single, Strip, or Grid. Read on-device image descriptions, visual details, and original recognized text. No accounts, analytics, or tracking.
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
image,viewer,photo,slideshow,JPEG,HEIC,thumbnail,EXIF,OCR,macOS,offline,sandbox
```

### What’s New

```
This release requires macOS 27 and Apple silicon.

• Apple Intelligence now receives image pixels directly to describe the visible scene and useful details on your Mac.
• Copy the description, refresh it, and expand original recognized text without losing repeated or later lines within the analysis limit.
• Analysis stays local, with clear unavailable/error states and cancellation when you navigate.
```

### URLs

| Field | Value |
|---|---|
| Support URL | https://github.com/vscarpenter/SimpleImageViewer/issues |
| Marketing URL | https://stillviewapp.com/ |
| Privacy Policy URL | https://stillviewapp.com/privacy.html |
| Website Terms of Use | https://stillviewapp.com/terms.html |

Both pages returned HTTPS 200 on September 15, 2026, with a September 6 effective date. The folder, sharing, and GitHub-draft corrections from `docs/reviews/2026-09-06-live-policy-copy.md` are live. The AI Insights section on both pages still describes the macOS 26 pipeline (Vision categories and face counts, and a language model that never receives image pixels) and names macOS 26. That copy is now wrong for 5.0.0; replacement wording is in `docs/reviews/2026-09-15-macos27-launch-readiness.md`. Publish it before submission. The website Terms URL is recorded for reference, not as confirmation of an App Store Connect EULA selection.

## App Privacy and review information

The app does not collect data, use analytics SDKs, or track users. Confirm that App Store Connect’s privacy answers match the signed binary and its `PrivacyInfo.xcprivacy` file. Local file access and required-reason API declarations are separate from data collection disclosures.

Complete the current age-rating questionnaire in App Store Connect using the actual product behavior: it displays user-selected local images and local analysis results, has no hosted content feed or account system, and does not generate images, audio, or video. Do not rely on a rating or questionnaire saved from an older release.

The project declares `ITSAppUsesNonExemptEncryption = NO`. Recheck the export-compliance answers for the submitted archive in App Store Connect.

## Screenshots and reviewer notes

Use current screenshots showing the actual app: Single, Strip, Grid, Info, Insights, and the read-only Shortcuts reference. The checked-in set in `marketing/screenshots-4.3.0/` predates native Settings and the Insights actions, so recapture before upload. Include an Insights result from an eligible Mac and an availability state if useful. Use dimensions accepted by the current App Store Connect uploader and avoid personal images.

Paste [AppStoreReviewNotes.md](AppStoreReviewNotes.md) into App Review Information → Notes. The app has no sign-in or demo credentials. Reviewers can use a local image folder.

## Pre-submission checks

- [ ] Verify 5.0.0 (40), the bundle ID, and the macOS 27 deployment target against the selected archive and App Store Connect.
- [ ] Set `releaseDate` in `Resources/whats-new.json` to the submission date so the in-app What's New sheet shows the right day.
- [ ] Run the repository’s lint and tests, and confirm CI for the exact submission commit.
- [ ] Create a distribution archive in Xcode and validate it in Organizer.
- [ ] Inspect the signed app’s entitlements with `codesign -d --entitlements - "<App>.app"`: App Sandbox, user-selected read-write files, and app-scope bookmarks are expected; `get-task-allow` must be absent from the distribution app.
- [ ] Verify `PrivacyInfo.xcprivacy` and the app icon exist inside the archived app’s `Contents/Resources` directory.
- [x] Verify the privacy and terms pages are publicly reachable over HTTPS.
- [ ] Publish the AI Insights policy-copy correction on both pages and recheck the privacy link from the distribution-signed app.
- [ ] Exercise opening/canceling a folder, viewer keyboard focus, Trash confirmation, narrow Grid layout, and all remaining preferences in the signed app.
- [ ] Exercise AI Insights on eligible hardware with the on-device model ready, plus its disabled/unavailable states.
- [ ] Upload the archive through Xcode Organizer, wait for processing, and select that build in App Store Connect.
- [ ] Review all metadata, privacy answers, age rating, screenshots, and reviewer notes before submission.

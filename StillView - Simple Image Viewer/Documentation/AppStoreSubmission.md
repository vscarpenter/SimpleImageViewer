# App Store Submission Package: StillView 5.1.0 (45)

Metadata for the 5.1 release on macOS 27. The project identity below matches the current Xcode project. Verify the signed archive, App Store Connect fields, and public privacy page before submission; this document does not confirm upload or approval.

## Version and identity

| Field | Value |
|---|---|
| Bundle ID | `com.vinny.StillView-Image-Viewer` |
| App Name | StillView - Image Viewer |
| Marketing Version | 5.1.0 |
| Build Number | 45 |
| Primary Category | Photo & Video (secondary: Utilities) |
| Minimum macOS | 27.0 |

Build 45 must exceed the last build uploaded to App Store Connect (5.0.0 shipped as build 44). If another build number is needed, run `scripts/update-version.sh --bump-build` and rebuild.

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
Open a folder and move through its images with arrow keys. Include subfolders to see every image together, then filter by branch in the folder tree or search by name. StillView reopens your last folder where you left off. Zoom, inspect at actual size, or fit an image to the window. Use fullscreen for a closer look.

THREE VIEWING MODES
Single keeps your attention on one image. Strip adds a docked filmstrip for navigation. Grid displays thumbnails with density and sorting controls. The Info inspector shows file details, dimensions, color information, and available EXIF camera metadata.

SUPPORTED FORMATS
JPEG, PNG, GIF, HEIF/HEIC, WebP, TIFF, and BMP. Animated GIF and WebP display their first frame only; multipage TIFF displays its first image. SVG and PDF are not supported.

ON-DEVICE INSIGHTS
AI Insights gives Apple Intelligence the selected image to describe its visible content on your Mac. Read a concise description and notable details, copy the description, or expand original recognized text. Text extraction also works with Insights off. Generated descriptions and OCR may contain errors. The app does not identify people.

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
BROWSE SUBFOLDERS
• Choose View > Include Subfolders to see every image in a folder and its subfolders together.
• A collapsible folder tree filters by branch, and search finds images by name or path.
• Refresh Folder (⌘R) picks up changes without reopening the folder.

PICK UP WHERE YOU LEFT OFF
• StillView reopens your last folder with the same image, sort, subfolder setting, filter, and search.

TEXT AND INSIGHTS
• Extract and copy text in an image even when AI Insights is off.
• Recognized text stays available if a description fails.
• Descriptions are shorter, and tall documents get a sharper text pass.

ALSO IN THIS RELEASE
• Up and Down move by row in Grid, and Return opens the selected image.
• Large folders show images while they are still being scanned.
• Recent folders keep their access, even on a disconnected drive.
• Creation-time sorting is now labeled Date Created.
```

5.0.0 (44) was submitted on September 15, 2026, with the rebuilt AI Insights, so this text covers only what changed after it.

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

The 5.0.0 set remains accurate for 5.1. Consider adding a Grid capture with Include Subfolders and the folder tree visible, since that is the headline 5.1 feature. Otherwise reuse the 5.0.0 set from `marketing/screenshots-5.0.0/appstore-captioned/` (or the clean `appstore/` set, not both): eight 2880×1800 PNGs captured on September 15, 2026, covering Single, Insights with a real on-device result, Grid, Strip, Info, 100% zoom, and the Shortcuts reference. Both pages of `marketing/screenshots-5.0.0/README.md` list the order and captions.

Paste [AppStoreReviewNotes.md](AppStoreReviewNotes.md) into App Review Information → Notes. The app has no sign-in or demo credentials. Reviewers can use a local image folder.

## Pre-submission checks

- [ ] Verify 5.1.0 (45), the bundle ID, and the macOS 27 deployment target against the selected archive and App Store Connect.
- [ ] Confirm `releaseDate` in `Resources/whats-new.json` (currently 2026-10-11) matches the submission date; changing it after archiving requires a new build.
- [ ] Run the repository’s lint and tests, and confirm CI for the exact submission commit.
- [ ] Create a distribution archive in Xcode and validate it in Organizer.
- [ ] Inspect the signed app’s entitlements with `codesign -d --entitlements - "<App>.app"`: App Sandbox, user-selected read-write files, and app-scope bookmarks are expected; `get-task-allow` must be absent from the distribution app.
- [ ] Verify `PrivacyInfo.xcprivacy` and the app icon exist inside the archived app’s `Contents/Resources` directory.
- [ ] Verify the privacy and terms pages are publicly reachable over HTTPS.
- [ ] Recheck that the privacy page still matches the app (on-device Vision text extraction now also runs with AI Insights off) and open the privacy link from the distribution-signed app.
- [ ] Exercise Include Subfolders, the folder tree filter, search, Refresh Folder, and quit/relaunch session restore in the signed app.
- [ ] Exercise opening/canceling a folder, viewer keyboard focus, Trash confirmation, narrow Grid layout, and all remaining preferences in the signed app.
- [ ] Exercise AI Insights on eligible hardware with the on-device model ready, plus its disabled/unavailable states.
- [ ] Upload the archive through Xcode Organizer, wait for processing, and select that build in App Store Connect.
- [ ] Review all metadata, privacy answers, age rating, screenshots, and reviewer notes before submission.

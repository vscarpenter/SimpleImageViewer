# App Store Submission Package — v4.0.0 (Build 29)

Everything you need to fill in App Store Connect, in one place. Copy each
field directly. Character limits are noted; everything below is within them.

---

## Version & identity (verify match in App Store Connect)

| Field | Value |
|---|---|
| Bundle ID | `com.vinny.StillView-Image-Viewer` |
| App Name (Display) | StillView - Image Viewer |
| Marketing Version | 4.0.0 |
| Build Number | 29 |
| Category (Primary) | Photography |
| Copyright | Copyright © 2025 Vinny Carpenter. All rights reserved. |
| Minimum macOS | 26.0 |

> **Verify before submitting:** Build 29 must be strictly greater than the
> last TestFlight or App Store build for v4.0.0. If you've previously uploaded
> a build numbered 29 or higher for the same version, bump `CURRENT_PROJECT_VERSION`
> in the pbxproj to 30 and rebuild.

---

## Metadata — copy/paste fields

### Subtitle (30 chars max)

```
Distraction-free image viewer
```
*(29 chars)*

### Promotional Text (170 chars max — editable any time without resubmitting)

```
AI Insights with Apple Intelligence: visually grounded notes that describe what your photos actually show, generated entirely on your Mac. No accounts, no telemetry.
```
*(165 chars)*

### Description (4,000 chars max)

```
StillView is a minimalist macOS image viewer designed for people who want a fast, clean, distraction-free way to browse photos. No accounts. No telemetry. No clutter — just your images, beautifully presented.

KEY FEATURES

Effortless Browsing
Open any folder of images and navigate with the keyboard. Arrow keys move between photos, +/- zoom, F or Enter goes fullscreen, Space advances or pauses a slideshow.

Universal Format Support
JPEG, PNG, GIF (animated), HEIF/HEIC, WebP, TIFF, BMP, SVG, and the first page of PDFs.

Advanced Viewing Modes
- Thumbnail strip — horizontal filmstrip for quick navigation
- Grid view — full-screen thumbnail grid for large collections
- Slideshow — automatic progression with customizable timing
- Image info overlay — file size, dimensions, EXIF, color profile, and more

AI Insights (macOS 26 + Apple Intelligence)
Generate concise, visually grounded notes about what an image actually shows — its subjects, scene, and recognizable text — using Apple's on-device Foundation Models framework. No images, metadata, prompts, or generated text ever leave your Mac.

Apple Intelligence is required and runs entirely on supported Macs. On ineligible devices, the AI Insights panel explains why the feature is unavailable and offers a direct link to the right place in System Settings.

Native macOS Experience
- Universal Binary (Intel and Apple Silicon)
- Full VoiceOver and accessibility support
- Dark Mode, high contrast, and reduced motion respected
- Fully customizable keyboard shortcuts with conflict detection
- Customizable appearance — glass effects, animation intensity, hover effects, toolbar style

Privacy & Security
- No internet connection required
- No data collection, no analytics, no tracking
- App Sandbox enabled with the Hardened Runtime
- Only reads folders you explicitly select
- Security-scoped bookmarks for persistent folder access

Whether you're sorting through a photo shoot, reviewing screenshots, or just appreciating a folder of images, StillView gets out of your way and lets you see.
```

### Keywords (100 chars max, comma-separated, no spaces after commas)

```
image,viewer,photo,slideshow,JPEG,HEIC,thumbnail,EXIF,Apple Intelligence,macOS,offline,sandbox
```
*(95 chars)*

### What's New in This Version (4,000 chars max)

```
StillView 4.0 brings AI Insights — powered by Apple Intelligence on macOS 26 — and substantial polish underneath.

NEW
• AI Insights with Apple Intelligence (macOS 26 + supported Macs). Open the inspector and choose Generate Insight to produce a short, content-focused description of any image. Apple Vision runs on-device to recognize scenes, text, and faces; Apple's Foundation Models framework synthesizes the result. Nothing leaves your Mac.
• Comprehensive Preferences with tabbed General, Appearance, and Shortcuts sections — live previews and full validation.
• Fully customizable keyboard shortcuts with conflict detection and import/export.
• Enhanced appearance controls: glass effects, animation intensity, hover effects, toolbar style.
• What's New screen so new features are easy to discover.

IMPROVEMENTS
• Vision-grounded insights — on-device scene categories, OCR text, faces, and saliency are treated as primary evidence; camera and EXIF metadata are treated as context only.
• Smaller, more honest AI results. Insights describe what the image shows, not the camera, and say so plainly when visual signals are sparse.
• Clear availability messages explain exactly why AI Insights is unavailable — macOS version, eligible hardware, Apple Intelligence disabled, or the on-device model still preparing — with a one-click jump to System Settings when relevant.
• Improved Dark Mode contrast across preferences and the main UI.
• Faster image loading and better memory handling for very large collections.
• Enhanced accessibility — high-contrast support and richer VoiceOver hints.

FIXES
• Thumbnail generation for some image formats.
• Window size and position persistence across launches.
• Keyboard shortcuts in specific UI states.

Privacy stays absolute: no network AI APIs, no telemetry, no analytics, no bundled Core ML models. Images, metadata, prompts, generated text, and analysis results never leave your Mac.
```

### URLs

| Field | Value |
|---|---|
| Support URL | https://github.com/vscarpenter/SimpleImageViewer/issues |
| Marketing URL (optional) | https://github.com/vscarpenter/SimpleImageViewer |
| Privacy Policy URL | https://github.com/vscarpenter/SimpleImageViewer#-privacy--security |

> If you have a dedicated `vinny.dev` privacy page, prefer that for Privacy Policy.

---

## App Privacy questionnaire answers

These match the `PrivacyInfo.xcprivacy` manifest now that the Photos entry has been removed.

| Question | Answer |
|---|---|
| Does this app collect data? | **No** |
| Does this app use third-party SDKs that collect data? | **No** |
| Does this app use tracking (cross-app/website)? | **No** |

Result: **"Data Not Collected"** badge on the App Store listing.

---

## Age Rating answers

Filled to produce a **4+** rating. The AI question is the one most likely to be reviewed for accuracy.

| Category | Frequency |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Graphic Sexual Content or Nudity | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Gambling Contests | No |
| Unrestricted Web Access | No |
| Medical/Treatment Information | No |
| **AI-generated content shown to the user** | **Infrequent/Mild** |

Justification for the AI question (paste into the comment field if asked):

> AI Insights produces a short textual description of the visible content of
> a user-selected local image, using Apple's on-device Foundation Models
> framework. All generation happens on device with Apple's built-in
> guardrails. The output is read-only descriptive text; no images, audio,
> or video are generated.

---

## Export compliance

Already declared in the binary via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`.
App Store Connect should accept the submission without prompting for export
compliance details. Classification: **5D992.c (exempt — uses only standard
system-provided HTTPS for user-initiated links).**

---

## Screenshots required (NOT in repo)

Minimum 1, maximum 10. Mac sizes accepted by App Store Connect:

- 1280 × 800 (Retina)
- 1440 × 900 (Retina)
- 2560 × 1600 (Retina)
- 2880 × 1800 (Retina)

Suggested screenshot set (4–6 images):

1. Main image viewer with a photo open and the toolbar visible
2. Grid view of a folder with thumbnails
3. Slideshow with the image-info overlay
4. AI Insights panel — generated result with title, summary, tags, and limitations
5. AI Insights panel — availability message ("Turn on Apple Intelligence…") with the Open System Settings button visible
6. Preferences → Shortcuts tab

Use the same Mac frame across all screenshots. Avoid personal images.

---

## App Review reviewer notes

Paste the contents of `Documentation/AppStoreReviewNotes.md` into the
**App Review Information → Notes** field. The file contains step-by-step
instructions for testing AI Insights on both eligible and ineligible Macs,
the privacy posture, sandboxing details, and export compliance summary.

You don't need to provide a demo account or sample images. There is no
sign-in flow.

---

## Pre-submission checklist

- [ ] Confirm `CURRENT_PROJECT_VERSION` (29) is strictly greater than the
      previous TestFlight/App Store build for 4.0.0.
- [ ] Bundle ID in App Store Connect listing equals `com.vinny.StillView-Image-Viewer`.
- [ ] Build a Release archive (Product → Archive in Xcode) and validate it
      via the Organizer before uploading.
- [ ] Verify entitlements on the signed Release `.app`:
      `codesign -d --entitlements - "StillView - Image Viewer.app"`
      must contain `com.apple.security.app-sandbox`,
      `com.apple.security.files.user-selected.read-write`,
      `com.apple.security.files.bookmarks.app-scope`, and (only in Release)
      MUST NOT contain `com.apple.security.get-task-allow`.
- [ ] Verify the privacy manifest is present in the bundle:
      `unzip -l "StillView - Image Viewer.app.ipa"` (or check Resources
      folder) shows `PrivacyInfo.xcprivacy`.
- [ ] Confirm `Assets.car` contains the 1024×1024 icon (already verified
      in Debug; re-verify after a Release archive with
      `assetutil --info "<App>/Contents/Resources/Assets.car"`).
- [ ] Upload via Xcode Organizer or `xcrun altool`. Wait for processing.
- [ ] Fill in App Store Connect using values from this document.
- [ ] Paste reviewer notes from `AppStoreReviewNotes.md`.
- [ ] Attach at least 1 screenshot.
- [ ] Submit for review.

## Post-submission

- TestFlight a build to at least one eligible Mac if possible before
  promoting to App Store, so AI Insights actually exercises end-to-end on
  Apple Intelligence hardware.
- Monitor for reviewer questions about the AI question or sandbox usage —
  the reviewer notes pre-answer the common ones.

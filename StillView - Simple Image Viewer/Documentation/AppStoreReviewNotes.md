# App Store Review Notes — StillView Image Viewer

Reviewer-facing context for the App Store Connect "Notes" field. Copy the relevant sections into the submission form. Updated for v4.0.0 (build 29).

## Testing AI Insights (macOS 26 + Apple Intelligence)

AI Insights uses Apple's on-device Foundation Models framework. There is no
account, no test credentials, and no network call to verify. Everything runs
locally.

### On an Apple Intelligence eligible Mac (M1 or later) running macOS 26+

1. Open **System Settings → Apple Intelligence & Siri** and enable Apple Intelligence.
2. Wait for the on-device model to finish downloading. Status is shown in
   System Settings; this can take several minutes on first activation.
3. Launch StillView and click **Select Folder** to open any folder with images
   (use the supplied sample images or your own).
4. Click any image to view it, then click the **sparkles icon** in the toolbar
   to open the AI Insights panel.
5. Click **Generate Insight**. After a few seconds, a content-focused
   description appears: a short title naming what the image shows, a summary,
   useful details, content tags, and the limitations of the analysis.

### On an ineligible Mac, or with Apple Intelligence disabled

The AI Insights panel still opens and shows an availability message explaining
why generation isn't available. Possible messages include:

- "AI Insights require macOS 26 or later."
- "This Mac does not support Apple Intelligence."
- "Turn on Apple Intelligence in System Settings to use AI Insights."
  *(an "Open System Settings" button is offered here)*
- "Apple Intelligence is preparing its on-device model. Try again later."

Please verify the panel opens and displays the correct message rather than
expecting generation to succeed in these states. The intent is graceful
degradation, not feature parity.

## Privacy posture

- Images, metadata, prompts, generated text, and analysis results never leave
  the device. There are no network AI APIs.
- No telemetry. No analytics. No crash-reporting SDK. No bundled Core ML
  models.
- Apple Vision (classification, OCR, face detection, saliency, horizon) runs on
  a background task at the moment the user clicks **Generate Insight**.
- The Foundation Models call is grounded in those on-device visual signals.
  Camera, EXIF, and GPS metadata are treated as context only and never as the
  image's subject.

## Sandboxing & permissions

- App Sandbox is enabled with the Hardened Runtime.
- Folder access is granted through `NSOpenPanel` (user-selected read-write).
- Folder access persists across launches via security-scoped bookmarks
  (app-scope).
- No network entitlement.
- No camera, microphone, photo library, or location entitlements.

## Sample test images

Any local folder works. For a thorough exercise that covers the AI Insights
prompt's different evidence paths:

- A scene photo (verifies visual classification)
- A photo of a sign, storefront, or product (verifies OCR-driven titles)
- A portrait or group photo (verifies face-count messaging)
- A mixed-format folder containing JPEG, PNG, HEIC, TIFF, and GIF (verifies
  format coverage)

## Export compliance

The app uses only HTTPS for user-initiated links to the developer's website
and the public GitHub repository (Help menu). Encryption is limited to
standard system-provided HTTPS. Export classification: 5D992.c (exempt).
Declared via `ITSAppUsesNonExemptEncryption = NO`.

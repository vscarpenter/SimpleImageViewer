# App Store Review Notes: macOS 27 development draft

Draft reviewer context for the next App Store submission. Assign a new release version and build before use. StillView requires macOS 27 or later. It has no account system, sign-in, or test credentials.

## Basic navigation

1. Launch StillView and choose **Open Folder**, or use **File → Open Folder… (⌘O)**. Select a local folder containing images.
2. Use **Single**, **Strip**, and **Grid** in the toolbar to switch viewing modes. At narrow widths the segments use icons, with accessible names and tooltips.
3. In Grid, click a thumbnail to select it, then double-click or press Enter with the viewer focused to open it in Single. Use the inline density slider to resize thumbnails. Sorting and additional image actions move into the toolbar’s More actions menu at narrow widths.
4. Open the inspector and choose **Info** for metadata or **Insights** for local image analysis.
5. The folder menu and **⌘O** can open another folder. Canceling the picker preserves the current collection. **B** with the viewer focused, or **File → Back to Folder Selection**, returns to the welcome screen.
6. Keyboard shortcuts apply to the image viewer when it has focus. Focused controls, text fields, dialogs, and other windows retain their usual key behavior. **Settings → Shortcuts** is a read-only reference.

Supported formats are JPEG, PNG, GIF, HEIF/HEIC, WebP, TIFF, and BMP. Animated GIF/WebP show their first frame; multipage TIFF shows the first image. SVG and PDF are excluded.

## Testing AI Insights

On an Apple Intelligence eligible Mac running macOS 27 or later:

1. Enable **System Settings → Apple Intelligence & Siri → Apple Intelligence** and wait for the on-device model to be ready.
2. Open a local image folder in StillView, select an image, and open the inspector’s **Insights** tab. **⌘I** opens this tab while the viewer has focus.
3. If the feature is disabled in StillView, choose **Enable Insights**. It can also be enabled in **Settings → Intelligence**.
4. Choose **Analyze image**. The result shows a description and notable visual details. Copy description copies its summary. Expand Text in image to read or copy original OCR text.
5. Try a scene photo, a sign or screenshot containing text, and a portrait. Apple Intelligence describes visible content; Vision supplies original OCR text. The app does not identify people.

The app passes the selected, oriented first-frame image directly to Apple's on-device Foundation Models framework. A fresh session generates a compact description, visual details, suggested tags, and specific uncertainties. Vision supplies exact OCR observations with repetition and location retained under an explicit evidence budget. Recognized text is displayed without model rewriting, and any truncation is disclosed. Inference errors show a recoverable failure; a failed refresh preserves the previous result.

Images, prompts, evidence, and results stay on the Mac. The operating system chooses the on-device model variant. No server model or older-OS fallback is used.

On an ineligible Mac, with Apple Intelligence disabled, or while its model is preparing, the panel explains why generation is unavailable. When appropriate, **Open System Settings** helps resolve that state. StillView’s normal image viewing remains available.

## Settings and file operations

- File-name display, opening the inspector by default, and slideshow duration apply on the next app launch.
- AI Insights and automatic image enhancements can be enabled or disabled in Intelligence. Enhancements change the displayed image; originals are preserved.
- Settings uses native macOS panes for General, Intelligence, and Shortcuts. The toolbar and controls follow system appearance and accessibility options. Command–Comma opens the most recently used pane.
- Slideshows always repeat after the last image. **S** starts or stops; Space stops an active slideshow and otherwise advances to the next image.
- Moving an image to Trash always requires confirmation of the named file. Test with a disposable image. Files can be recovered from macOS Trash.

## Privacy and permissions

- The app does not collect user data or use analytics, tracking, or third-party crash-reporting SDKs.
- Images, metadata, recognized text, model input, and results remain on this Mac. No network AI API or bundled custom Core ML model is used.
- App Sandbox and Hardened Runtime are enabled. `NSOpenPanel` grants user-selected read-write folder access so a confirmed file can be moved to Trash.
- App-scope security-scoped bookmarks are stored locally for folder access.
- No camera, microphone, photo-library, or location entitlement is requested. The app has no network entitlement.
- Sharing opens macOS sharing services when the user chooses Share. Privacy, support, and website links open in the user’s browser when selected.
- Privacy policy: https://stillviewapp.com/privacy.html

The app declares `ITSAppUsesNonExemptEncryption = NO`.

# App Store Review Notes: StillView 5.0.0 (44)

Paste the text below this line into App Review Information → Notes. It is plain text sized for the field's 4,000-character limit.

---

StillView requires macOS 27 or later on Apple silicon. It has no account system, sign-in, or test credentials. Reviewers can use any local folder of images.

BASIC NAVIGATION
1. Launch StillView and choose Open Folder, or use File > Open Folder… (⌘O). Select a local folder containing images.
2. Use Single, Strip, and Grid in the toolbar to switch viewing modes.
3. In Grid, click a thumbnail to select it, then double-click or press Enter to open it in Single. The density slider resizes thumbnails.
4. Open the inspector and choose Info for metadata or Insights for local image analysis.
5. ⌘O opens another folder. Canceling the picker keeps the current collection. B with the viewer focused, or File > Back to Folder Selection, returns to the welcome screen.
6. Keyboard shortcuts apply when the image viewer has focus. Focused controls, text fields, dialogs, and other windows keep their usual keys. Settings > Shortcuts is a read-only reference.

Supported formats: JPEG, PNG, GIF, HEIF/HEIC, WebP, TIFF, and BMP. Animated GIF and WebP show their first frame; multipage TIFF shows the first image. SVG and PDF are excluded.

TESTING AI INSIGHTS
On an Apple Intelligence eligible Mac running macOS 27 or later:
1. Enable System Settings > Apple Intelligence & Siri > Apple Intelligence and wait for the on-device model to be ready.
2. Open a local image folder, select an image, and open the inspector's Insights tab (⌘I while the viewer has focus).
3. If the feature is off in StillView, choose Enable Insights, or enable it in Settings > Intelligence.
4. Choose Analyze image. The result shows a description and notable visual details. Copy description copies the summary. Expand Text in image to read or copy the original OCR text.
5. Try a scene photo, a sign or screenshot with text, and a portrait. Apple Intelligence describes visible content; Vision supplies the OCR text. The app does not identify people.

The app passes the selected, oriented first-frame image to Apple's on-device Foundation Models framework. A fresh session generates a compact description, visual details, suggested tags, and specific uncertainties. Recognized text is shown without model rewriting, and any truncation is disclosed. Inference errors show a recoverable failure; a failed refresh keeps the previous result.

Images, prompts, evidence, and results stay on the Mac. No server model or older-OS fallback is used.

On an ineligible Mac, with Apple Intelligence disabled, or while its model is preparing, the panel explains why generation is unavailable and can open System Settings. Normal image viewing remains available.

SETTINGS AND FILE OPERATIONS
- AI Insights and automatic image enhancements can be turned on or off in Intelligence. Enhancements change the displayed image only; originals are preserved.
- Settings uses native macOS panes for General, Intelligence, and Shortcuts. ⌘, opens the most recently used pane.
- Slideshows repeat after the last image. S starts or stops; Space stops an active slideshow and otherwise advances.
- Moving an image to Trash always requires confirmation of the named file. Test with a disposable image; files can be recovered from macOS Trash.

PRIVACY AND PERMISSIONS
- No user data collection, analytics, tracking, or third-party crash reporting.
- Images, metadata, recognized text, model input, and results stay on this Mac. No network AI API or bundled custom Core ML model.
- App Sandbox and Hardened Runtime are enabled. NSOpenPanel grants user-selected read-write folder access so a confirmed file can be moved to Trash. App-scope security-scoped bookmarks are stored locally.
- No camera, microphone, photo-library, location, or network entitlement.
- Share opens macOS sharing services. Privacy, support, and website links open in the browser when selected.
- Privacy policy: https://stillviewapp.com/privacy.html
- ITSAppUsesNonExemptEncryption = NO.

# App Store Review Notes: StillView 5.1.0 (45)

Paste the text below this line into App Review Information → Notes. It is plain text sized for the field's 4,000-byte limit; count the UTF-8 payload after the separator.

---

StillView requires macOS 27 or later on Apple silicon. It has no account system, sign-in, or test credentials. Reviewers can use any local folder of images.

BASIC NAVIGATION
1. Launch StillView and choose Open Folder, or use File > Open Folder… (⌘O). Select a local folder containing images.
2. Use Single, Strip, and Grid in the toolbar to switch viewing modes.
3. In Grid, click a thumbnail to select it, then double-click or press Enter to open it in Single. The density slider resizes thumbnails.
4. Open the inspector and choose Info for metadata or Insights for local image analysis.
5. ⌘O opens another folder; canceling keeps the collection. File > Back to Folder Selection returns to the welcome screen and disables image commands.
6. Viewer shortcuts apply when the viewer has focus. Controls, text fields, dialogs, and other windows keep their usual keys. Settings > Shortcuts lists the commands.

SUBFOLDERS AND SESSIONS (NEW IN 5.1)
1. Choose View > Include Subfolders to combine images from the folder and its subfolders. The folder tree filters by branch; Filter images… searches by name or path.
2. View > Refresh Folder (⌘R) rescans without reopening the folder.
3. On relaunch, StillView restores the last accessible folder, selected image when available, sort, scope, filter, and search using its stored security-scoped bookmark.

Supported formats: JPEG, PNG, GIF, HEIF/HEIC, WebP, TIFF, and BMP. Animated GIF and WebP show their first frame; multipage TIFF shows the first image. SVG and PDF are excluded.

TESTING AI INSIGHTS
On an Apple Intelligence eligible Mac running macOS 27 or later:
1. Enable System Settings > Apple Intelligence & Siri > Apple Intelligence and wait for the on-device model to be ready.
2. Open a local image folder, select an image, and open the inspector's Insights tab (⌘I while the viewer has focus).
3. If the feature is off in StillView, choose Enable Insights, or enable it in Settings > Intelligence.
4. Choose Analyze image for a concise title and summary. Copy description copies the summary. Expand Text in image to read or copy recognized words.
5. Extract text runs Vision independently, even with Insights off. Image preparation shows progress and Cancel.
6. Try a scene photo, a sign or screenshot with text, and a portrait. Apple Intelligence describes visible content; Vision supplies the OCR text. The app does not identify people.

Descriptions use on-device Foundation Models; Vision supplies text without model rewriting. Both may contain errors; partial extraction is marked. Failed descriptions retain OCR; failed refreshes of unchanged images keep prior results. Edited-image reloads clear old Insights. Check Again refreshes model readiness.

On an ineligible Mac, with Apple Intelligence disabled, or while its model is preparing, the panel explains why and can open System Settings. Viewing and text extraction remain available.

SETTINGS AND FILE OPERATIONS
- AI Insights and automatic image enhancements can be turned on or off in Intelligence. Enhancements change the displayed image only; originals are preserved.
- Slideshows repeat after the last image. S starts or stops; Space stops an active slideshow and otherwise advances.
- Moving an image to Trash always requires confirmation of the named file. Test with a disposable image; files can be recovered from macOS Trash.

PRIVACY AND PERMISSIONS
- No user data collection, analytics, tracking, or third-party crash reporting.
- Images, recognized text, model input, and results stay on this Mac. No network AI API or custom Core ML model.
- App Sandbox and Hardened Runtime are enabled. NSOpenPanel grants user-selected read-write folder access so a confirmed file can be moved to Trash. App-scope security-scoped bookmarks are stored locally.
- No camera, microphone, photo-library, location, or network entitlement.
- Privacy policy: https://stillviewapp.com/privacy.html
- ITSAppUsesNonExemptEncryption = NO.

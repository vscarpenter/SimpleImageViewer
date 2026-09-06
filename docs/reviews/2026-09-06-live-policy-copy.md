# Live policy page verification

Verified September 6, 2026 against app commit `c350a6f`. Both URLs returned HTTP/2 200 over HTTPS with HTML content and a September 6 effective date:

- [Privacy policy](https://stillviewapp.com/privacy.html), checked at 22:41:50 UTC; ETag `c4f52403ad51cfb3ae96becb4ee676cb`.
- [Terms of use](https://stillviewapp.com/terms.html), checked at 22:41:41 UTC; ETag `68b51df3b0ec85caa0b50ed336808a7f`.

Publication is verified. Four factual copy corrections remain. The wording below is ready for the app owner to adapt and publish; no website or legal clauses were changed by this review.

## 1. Privacy: previous folders and settings

The folders section describes a startup-folder toggle removed during Settings cleanup. The storage section names inactive toolbar-style and zoom controls. Describe the actual local storage without promising those controls.

Suggested replacement for the second paragraph under **Your photos and folders**:

> StillView stores recent folders and can restore a previous viewing session. Security-scoped bookmarks let the sandboxed app retain access to folders you selected. These records stay in the app’s container on your Mac. You can clear the recent-folder list from the welcome screen.

For **Preferences and local storage**, use current examples: file-name display, inspector visibility at launch, slideshow duration, AI Insights, and image enhancements. Preferences, window state, and preference backups remain local.

Evidence: [PreferencesTabView.swift](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/PreferencesTabView.swift:346>) and [ContentView.swift](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/ContentView.swift:351>).

## 2. Privacy: user-initiated sharing

Qualify the introduction and summary claims that data always stays on the Mac. Remove the metadata paragraph’s claim that the clipboard is its only possible destination. Add the system Share action to **Network access**:

> StillView does not automatically collect or upload your images. Viewing and AI analysis happen locally. If you choose Share, StillView passes the original image to the macOS sharing service you select. That service may transfer the image, including embedded metadata such as location, to your chosen recipient or destination under its own privacy policy. Clipboard contents are handled by macOS and other apps you choose to use.

Evidence: [ImageViewerViewModel.swift](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift:894>) passes the original image URL to `NSSharingServicePicker`.

## 3. Privacy: GitHub feedback drafts

The feedback paragraph implies nothing is transmitted until submission. Opening the prefilled GitHub URL already sends its query data to GitHub; posting the issue remains a separate user action.

Suggested replacement for the feedback bullet under **Network access**:

> Send Feedback opens a GitHub issue draft or an email draft addressed to stillview@vinny.dev. The draft includes the app version, build number, macOS version, processor type, and whether AI Insights is enabled. Opening GitHub feedback sends this prefilled technical information to GitHub in the URL so it can display the draft. You can edit the draft before posting. The email command opens a draft in your mail app and does not send it automatically.

Evidence: [FeedbackService.swift](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Services/FeedbackService.swift:41>) builds the query and opens it in the browser.

## 4. Both pages: Apple Intelligence’s role

The Terms AI section attributes photo descriptions to Apple Intelligence. In this release Vision supplies visual matches, recognized text, and face counts. Foundation Models can select existing text lines; it does not receive image pixels or write image descriptions.

Suggested opening paragraph for each page’s **AI Insights** section:

> AI Insights uses Apple Vision on your Mac to identify visual categories, recognize text, and count faces. When suitable text is available, Apple’s on-device Foundation Models framework can select useful existing text lines. The app displays those lines without rewriting them; the language model does not receive image pixels. Visual matches can be incomplete or incorrect and do not identify people.

Keep the existing availability and accuracy qualifications. Evidence: [AppleIntelligenceInsightsService.swift](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Services/AppleIntelligenceInsightsService.swift:56>).

## Verification boundary

Local-only analysis, no cloud fallback, and sandbox permissions agree with current source. Public HTML inspection does not establish private AWS logging settings or App Store Connect configuration. Recheck the revised live copy before submission.

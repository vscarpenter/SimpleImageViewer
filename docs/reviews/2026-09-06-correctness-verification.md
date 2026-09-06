# Viewing and Insights verification

Implementation branch: `codex/viewing-and-insights-correctness`.

## Core viewing

The test target now imports the built application module. Xcode's UI was used to configure the host application, remove duplicated production compilation, and add the restored and new test sources. Both CI workflows check that the required suites remain in the app-hosted target.

Runtime walkthrough used the current Debug app from `/tmp/stillview-fixes-derived/Build/Products/Debug`, the repository's 14 sample photos, and two disposable corrupt JPEG fixtures in `/tmp`:

- Fit shows the entire image centered with the stage insets; 100% shows original pixel detail and a visibly different crop.
- Mouse dragging at 100% retains the released position. Repeated dragging reaches the image boundary and stops without exposing empty stage space. Fit restores the centered full image.
- Full-screen entry and exit retain a valid viewport.
- A folder containing only two corrupt JPEGs stops after trying both, shows “Unable to display image” with an explanation, and offers Retry. Retry runs another bounded attempt and returns to that error state. Reopening the sample folder succeeds.

An independent review found no introduced blocker. Additional probes verified exact alternating-pixel rendering at 100% on a 2× display and consistent cache accounting after 20,000 concurrent operations. Its finding that canceled queued work could repopulate a cleared cache was incorporated into the loader follow-up.

Coverage limits: gesture mathematics and mouse dragging are covered; a physical trackpad pinch has not been performed. Capacity-eviction tests exercise the explicit cache bound, not a forced operating-system `NSCache` eviction. Controlled enhancement and metadata continuations test genuinely late completion; publisher tests also benefit from Combine subscription cancellation.

Final core run: **135 tests passed, zero failures**, using `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -derivedDataPath /tmp/stillview-fixes-derived -resultBundlePath /tmp/stillview-core-tests-final.xcresult CODE_SIGNING_ALLOWED=NO`. The loader cancellation regressions cover queued and running loads/preloads, subscriber coalescing, clear/reload of the same URL, and discarded cache insertion. `python3 scripts/check-test-target.py` verified 15 active source files. SwiftLint completed with six existing warnings and zero serious violations; `git diff --check` passed.

## Insights implementation contract

Photo descriptions are assembled from supported Vision observations. The language model receives no image pixels on macOS 26. For longer recognized text, guided generation selects existing line indices; the app validates those indices and displays the exact original OCR lines. Model prose cannot enter the result. Existing platform availability requirements remain in this pass.

Specificity uses explicit parent/child relationships and a confidence margin, with regression fixtures from the reviewed classifications. Short and CJK text must not produce a “no readable text” result. Retention is in memory, bounded, and invalidated when the file revision changes.

Final suite counts and current-build Insights observations will be recorded after integration. No release, CI, or App Store result is implied by local verification.

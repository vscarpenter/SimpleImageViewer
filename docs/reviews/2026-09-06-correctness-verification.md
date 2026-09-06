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

## Insights results

The live production-service probe ran on macOS 26.6.2 with Apple Intelligence available. It used the same four repository photos and STOP fixture as the initial review, plus generated CJK and receipt fixtures. Image-file and logging adapters were local CLI stubs; the perception, classifier, result builder, metadata service, validator, and Apple Intelligence service were compiled from the current source. The running Debug app independently reproduced the Alley, STOP, 東京駅, and receipt results. Nothing was uploaded.

| Input | Before | Verified result |
| --- | --- | --- |
| Brick alley | Path | Alley, 96% Vision category confidence |
| Raspberries | Berry, with an unsupported table claim | Raspberry, 83%; no invented table relationship |
| Forest waterfall | Liquid | Waterfall, 89% |
| City from above | Structure, with “liquid on top” wording | Skyscraper, 81%; no invented spatial relationship |
| STOP fixture | No reliable visual match / no readable text | Text: STOP; the exact OCR line is visible |
| CJK fixture | Additional coverage | Text: 東京駅; the exact OCR line is visible |
| Seven-line receipt | Additional coverage | Apple Intelligence selected “Invoice 1042”, “TOTAL $19.95”, and “PAID SEPTEMBER 5”; all seven original OCR lines remain available |

Confidence values above are Vision scores, not measured accuracy. This small sample checks the reported regressions; it is not a model-quality benchmark. Raw observations and results are in [the live evidence](2026-09-06-ai-live-evidence.txt).

Runtime walkthrough also verified that the disabled Insights tab stays selected, Enable changes the action to Generate, existing Settings reflects opt-in, and Info/Insights switching preserves a completed result. Replacing a disposable PNG at the same URL, then refreshing Insights, reloads the displayed pixels and removes the obsolete result. STOP → 東京駅 → receipt remained consistent between the image and generated result. The receipt highlights identify their source, and the disclosure reveals all recognized text. Redundant “Likely content” repetition was removed from the inspector presentation.

Automatic app-activation handling, in-flight/canceled refresh preservation, typed perception failures, LRU eviction, same-size/date-only changes, cache replacement/deletion, remembered-tab restoration, and Settings feedback prevention are covered by controlled app-hosted tests. In-flight file changes are checked against an immutable predecode revision; changed images return an actionable Retry error rather than publishing or caching old pixels. Info metadata is keyed by URL and load identity and refreshes file size/date alongside extracted metadata.

The result cache is in memory and bounded to 20 entries. Revisions use exact byte count and modification date; deliberately changing bytes while preserving both is outside this fingerprint's detection. Physical trackpad gestures, signed distribution builds, remote CI, and App Store release validation were not performed. Remaining legacy test files outside the active target are not claimed as covered.

## Final verification

The complete active app-hosted suite passed: **188 tests, zero failures**, including the final metadata refresh, inspector presentation, and six path-alias regression tests. The Insights implementation boundary had 182 passing tests before this runtime follow-up.

```sh
xcodebuild test -project 'StillView - Simple Image Viewer.xcodeproj' \
  -scheme 'StillView - Simple Image Viewer' -destination 'platform=macOS' \
  -derivedDataPath /tmp/stillview-fixes-derived \
  -resultBundlePath /tmp/stillview-final-188.xcresult CODE_SIGNING_ALLOWED=NO
python3 scripts/check-test-target.py
swiftlint lint --no-cache --reporter github-actions-logging
git diff --check
```

The membership check verified 16 active test source files. SwiftLint reported six existing warnings and zero serious violations across 96 production source files. The diff whitespace check passed. Independent review confirmed all identified blockers resolved, including stale Info metadata and file revision races.

After the Mac was unlocked, the final metadata refresh and redundant-label removal changes were verified visually in a freshly launched build. For this walkthrough, `xcodebuild build` used the same project, scheme, destination, and derived-data path with `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES`; the local ad-hoc build succeeded and embedded the app's sandbox/file-access entitlements. This is development validation, not a distribution signature or release validation.

- The receipt panel displayed exact text highlights and all seven OCR lines without the removed “Likely content” section.
- Replacing the same PNG with the Japanese sign, then switching Info → Insights → Info, refreshed the visible pixels, dimensions from 1600 × 1320 to 1600 × 600, size from 122 KB to 29 KB, and modified time from 8:57 PM to 10:09 PM. The obsolete receipt insight was cleared, and fresh generation returned `Text: 東京駅`.
- The recheck exposed an existing raw-path comparison issue: enumerating `/tmp/stillview-runtime-revision` can produce children under `/private/tmp/stillview-runtime-revision`, causing the access registry to reject the same folder. The canonical path loaded successfully. The follow-up normalizes containment comparisons while preserving the original security-scoped URLs; opening the folder through `/tmp` then succeeded in the final sandbox-enabled build.

The six added regressions cover current/favorite alias access, `/tmp` equivalence including a missing leaf, sibling prefix rejection, symlink escape rejection, and non-file URLs. Tests use independent access-manager instances so they cannot stop the application's current security scope. Independent review found no production blocker; its test-isolation concern was incorporated before the final 188-test run.

After the walkthrough, the original Insights opt-in setting was restored to off and the two disposable `/tmp` fixture folders were removed from Recents.

The subsequent sandbox-enabled walkthrough preserved that profile's existing Insights setting and removed its temporary recent-folder entry with the matching bookmark.

No release, CI, or App Store result is implied by local verification.

# 5.1 release-readiness fixes: verification

Implemented the approved bookmark, Folder Selection menu and stale-Insights corrections against `3fb4803d6a448ce18160eb4933c68b8bfcde5e09`. Functional source commit: `a79e1cf7eeddbbb2142effb6ef7e23c84c1555b1`. Release identity remains **5.1.0 (45)** on macOS 27 / Apple silicon.

## Delivered behavior

- Legacy grants remain available for later reconciliation after temporary resolution failure. Association uses standardized folder identity, never legacy array position. Removed/cleared eligibility cannot return on retry, fresh grants take precedence, and stale preference snapshots cannot erase recovered grants. Selecting an unavailable legacy recent folder retains its recovery record.
- Startup resolves and validates provider access off the main actor with no-mount options and balanced temporary scopes. Explicit navigation cancels delayed session restoration, including cancellation before the queued AppDelegate task begins. Early autosaves and synchronous state saving remain covered. Bookmark map/set reads and writes are synchronized; provider and preference operations stay outside the lock.
- Folder Selection withdraws image, refresh and subfolder menu commands while retaining the saved collection. Leaving the viewer stops slideshow and Insights/OCR activity. A visible empty collection can still refresh; Open Folder and Back remain available.
- Known changed revisions invalidate description/OCR before replacement image or metadata loading, including folder Refresh. Async preparation exposes progress and Cancel, hides unverified results and copy controls, and rejects repeated actions and stale completions. Unchanged-file refresh preserves accepted evidence after a description failure; independent OCR intent survives AI being turned off.
- Bundled What’s New, CHANGELOG, Store submission copy, review notes and architecture documentation describe the current release. The provisional October 11 release date and previous release history are preserved.

## Automated and build evidence

Environment: macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), SDK 27, arm64 Mac mini. Xcode operations were serialized.

| Check | Result |
|---|---|
| Initial behavioral RED | 10 tests executed; 26 assertions failed before fixes |
| Additional same-URL Refresh RED | Compiled; the two old-description/OCR assertions failed |
| Focused GREEN | 51 tests passed, zero failures |
| Final full app-hosted Release suite | **335 passed, zero failed, zero skipped**; 28 more than the reviewed base |
| Test membership | All 15 active test sources verified against the app host |
| Normal Debug build | Passed, including the existing local DEBUG helper |
| Normal Release archive | Passed with signing disabled |
| SwiftLint | Zero serious violations; one existing PreferencesViewModel complexity warning |
| Whitespace | `git diff --check` passed |
| Independent integration review | No remaining concrete findings in frozen source, including startup lock boundaries |

The result bundle reports no test runtime warnings. The local runtime log captured for the verification process had no `Publishing changes from within view updates` or `Modifying state during view update` messages during this walkthrough; this is a bounded observation, not a general performance guarantee. Framework AppIntents/Spotlight connection messages were present. An intermediate compile failure was corrected before GREEN; an initial lint invocation used Command Line Tools and was rerun successfully with the Xcode developer directory selected.

[Full suite summary](evidence/2026-10-12/release-fixes-full-test-summary.json), [GREEN excerpt](evidence/2026-10-12/release-fixes-full-green.txt), [focused summary](evidence/2026-10-12/release-fixes-focused-test-summary.json), [initial RED](evidence/2026-10-12/release-fixes-red.txt), and [Refresh RED](evidence/2026-10-12/release-fixes-refresh-red.txt).

## Native observations

Inspected an ad hoc signed, hardened-runtime copy of the new Release archive with the unchanged three sandbox/folder entitlements. Strict signature verification passed. These observations come from the actual accessibility tree and screenshots:

1. Back to Folder Selection disabled every Image menu action, including Next, Slideshow, Copy, Share, Reveal and Trash. View mode, inspector, zoom, Include Subfolders and Refresh were also disabled. ⌘R left Folder Selection visible. No Share or Trash action was executed.
2. Help → What’s New opened version 5.1.0 with three sections and eight items. Scrolling reached all three latest bug-fix entries, and the close control worked.
3. The controlled recursive folder opened with five images. Expanding Travel showed Italy (two images) and Japan (one). Selecting Italy filtered to two images; searching `receipt` selected the one matching image.
4. With AI Insights temporarily off, Vision extraction completed with **47 lines**, including the receipt’s subtotal, tax and total. The text disclosure and Copy text control were available. Re-enabling the original AI preference retained the recognized text.
5. Restarting only the temporary verification copy restored the root, recursive scope, `receipt` query, receipt image and Italy filter. The source list showed Italy selected after expanding Travel. This used previously autosaved state and a process restart; it was not a successful native Cmd-Q verification.

Later menu activation again returned stale-element errors and screenshots became unavailable. The first ⌘R attempt with an unchanged image left its 47-line result visible, but subsequent menu-driven Refresh could not be completed reliably. A native changed-file reproduction could not be performed because the shell could not access the Documents fixture; no fixture modification occurred. The changed-revision, held-metadata, preparation/cancellation and delayed/disconnected-provider boundaries are instead covered by controlled automated regressions. Real disconnected network/provider behavior and a full AI description quality evaluation were not revalidated in this pass.

[Native GREEN observations](evidence/2026-10-12/release-fixes-native-green.txt), [native RED menu observation](evidence/2026-10-12/release-fixes-native-red.txt), and [signature inspection](evidence/2026-10-12/release-fixes-native-signature.txt).

## Packaging, copy and preservation

The archive is `/tmp/stillview-release-fixes-2026-10-12.xcarchive`; unsigned executable SHA-256: `eb365dca4c4f79f3508ab04d1eec3f0f037e9d08af550abeee4cd3f98b879fd6`. What’s New and the privacy manifest match source byte for byte. The archive is arm64, minimum macOS 27.0, version 5.1.0 (45). The snapshot menu, helper type and dynamic CGWindowListCreateImage symbol string are absent from the Release executable.

Store copy fits current field limits: subtitle 29/30 characters, promotion 160/170, description 2,590/4,000, keywords 97/100 UTF-8 bytes, What’s New 1,724/4,000 characters, review notes **3,958/4,000 UTF-8 bytes**. [Copy evidence](evidence/2026-10-12/release-fixes-copy-validation.json) and [bundle validation](evidence/2026-10-12/release-fixes-validation.json) record the exact checks.

The user’s existing DEBUG screenshot helper remains uncommitted and unchanged. Its original diff SHA-256 is `82438b26a4237c3ba90af16f2bb55a903edba03db3a1e7e80fca47ec01b44ae2`; `SimpleImageViewerApp.swift` is excluded from these commits. No Xcode project or entitlement edits, website publication, App Store upload or merge were performed.

## Remaining submission gates

Validate the actual distribution-signed archive and provisioning in Xcode Organizer; verify build-number availability, metadata, privacy answers and age rating in App Store Connect; finish current 5.1 screenshots; and reconcile the public privacy/support pages with independent OCR and current contact information. Confirm the provisional release date before submitting, rebuilding if changed. The unsigned archive and local ad hoc runtime copy do not establish Store submission approval. Hosted checks are reported separately on the PR; CodeQL remains paused in the existing repository workflow.

## Craft report

Checked native command scope, source-list filtering, inspector preparation/result/recovery states, release-copy readability and reachability, and sandboxed restoration. Passed the observed native menu, What’s New, branch/search and independent OCR flows plus the automated lifecycle matrix. Preserved the existing SF typography, native palette and controls, image-first layout and restrained motion. The behavioral corrections are ready for review; the remaining native bounds and external submission gates above still apply.

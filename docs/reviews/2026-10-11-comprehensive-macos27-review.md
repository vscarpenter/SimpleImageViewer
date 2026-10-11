# StillView: macOS 27, usability, and image-insights review

Reviewed October 11, 2026 against `main` at `9da3f3fe853febdb47828654de7f348072c25e98`, version 5.0.0 (44).

StillView already has the right platform foundation: macOS 27 and Apple silicon, direct image input to the on-device Foundation Models model, bounded image decoding, revision-aware main-image and Insights caching, and native Settings. The next investment should improve browsing correctness, keyboard use, text extraction, and responsiveness. A visual rewrite or another AI backend would not address the strongest findings.

This review changes documentation only. Implementation recommendations below are proposals. Evidence combines current source inspection, a fresh build/test/lint pass, a limited native walkthrough, isolated production-scanner and AppKit probes, current hosted CI results, and a fresh local AI regression run. No private-photo library was searched, no image was uploaded, and no AI preference was changed.

User direction confirmed October 11: prioritize **more accurate descriptions and text recognition**. Recursive browsing should show **all images together, with a folder tree for filtering**. The tree is part of the requested feature and may be collapsed; it is not an optional follow-on feature.

## Verification and its limits

| Check | Current result | What it establishes |
| --- | --- | --- |
| Host/toolchain | macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), SDK 27.0, arm64 | Validation on a current Golden Gate host. Xcode was selected per command; the global developer-directory setting remains untouched. |
| App-hosted tests | **229 passed, zero failures**, 15 compiled test files | Meaningful viewing, access/picker, OCR, validator, cache, and lifecycle regressions pass. Model output is mocked in controlled tests. |
| Test membership | Required-source checker passed | Required regression suites are included. There are 71 Swift test files on disk; 56 are outside the target. That is a coverage-maintenance gap, not 56 demonstrated bugs. |
| Release build | **Succeeded**, arm64, signing disabled | Current source compiles for macOS 27. The build tool emits an App Intents metadata-extraction warning because the app has no App Intents dependency; no Swift compiler warning/error was found. |
| SwiftLint | **Zero errors, one complexity warning** | `PreferencesViewModel.swift:671` has complexity 16 against a limit of 15. Configuration also declares a disabled line-length rule. |
| Native walkthrough | Folder opening; Single/Grid; Info/disabled Insights; native General/Intelligence Settings; grid arrows; Single context menu; View menu | Down Arrow does not change grid selection; Right Arrow does. Single right-click exposes no menu. View exposes only system tab/full-screen commands. Full VoiceOver, contrast, dark appearance, large folders, and production sandbox behavior remain unverified. |
| Production scanner probe | Shallow/recursive, hidden subtree, package, repeat identity, pre-cancellation | Both modes ignore pre-cancellation; recursive scanning enters `.app` package resources; the same file gets a new UUID on each scan. |
| AppKit lifetime probe | Temporary delegate deinitializes after explicit autoreleasepool drain | Confirms missing ownership of a weak window delegate. The native close/reopen attempt was inconclusive; no unrecoverable app-window failure is claimed. |
| Fresh AI regression | **28/30 returned results; all 14 repository photos succeeded** | Genuine current production inference works, but a receipt failed validation and an adversarial screenshot was refused. Completion is not semantic accuracy. |
| Hosted CI | September 15 Build/Test and CI passed; September 28 and October 5 scheduled CodeQL failed | All four inspected runs target this HEAD. CodeQL failed before analysis, so the current security-analysis gate is incomplete. |

Build/test/lint logs are retained under `/tmp/stillview-review-{release,tests,lint}-2026-10-11.log`; the result bundle is `/tmp/stillview-review-tests-2026-10-11.xcresult`. Compact, durable findings/probe/AI/CI evidence is linked below.

Apple confirms the macOS 27 SDK ships with Xcode 27. This app's target and local toolchain are already aligned with that platform. [Apple release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes).

## Recommended order

1. **Make browsing predictable:** fix sort/selection restoration, recent-folder bookmark associations, window-delegate ownership, grid navigation, and filename behavior.
2. **Keep text useful even when AI fails:** publish OCR independently of a generated description, retaining the existing stale-result and cancellation protections.
3. **Remove unnecessary work from browsing:** defer synchronous Insights metadata preparation and introduce bounded, reusable thumbnail scheduling.
4. **Measure description quality:** evaluate smaller task-specific output, meaningful uncertainty, and better document OCR against fixed local fixtures.
5. **Deliver recursive browsing on those foundations:** one combined collection with a collapsible folder tree for filtering, explicit scope, incremental/cancellable discovery, stable identities, relative paths, package policy, and partial-error handling. See the [feature proposal](../specs/2026-10-11-recursive-folder-browsing-proposal.md).

## Usability review

The image is visually dominant, Single/Strip/Grid are easy to find, Settings follows familiar Mac conventions, and the inspector uses progressive disclosure. Preserve these strengths. The highest-impact UI work is functional and does not require new decorative materials.

| Before | After | Why / evidence |
| --- | --- | --- |
| Grid responds to Left/Right but has no row-aware Up/Down; stage focus styling is disabled. | Explicit grid selection/focus, a visible focus ring, Up/Down based on the current column count, and Return to open. | **High; live and source confirmed.** `Services/KeyboardHandler.swift:50`, `Views/GridPane.swift:104`, `App/ContentView.swift:142`. Controls and text inputs must retain their own arrow keys. Verify resizing changes the row step without changing the selected image. |
| Single has no image context menu; View has only system commands. Copy image/path and Reveal in Finder are discoverable through Grid/Strip menus. | Scene-focused View/Image commands and the existing image context actions on Single. | **High; live confirmed.** `App/SimpleImageViewerApp.swift:83`, `Views/ContextMenuProvider.swift:11`. Expose modes, Fit/100%/zoom, inspector, slideshow, copy, and Reveal in Finder consistently. The menu should show shortcuts and disable actions without an image. |
| General Settings offers “Show file names,” but no active view renders conditionally from that preference. | Implement an optional filename caption and name its scope clearly, such as “Show filename below image.” | **Medium; source confirmed.** `Views/PreferencesTabView.swift:30`, `App/ContentView.swift:299`, `ViewModels/ImageViewerViewModel.swift:158`. The project brief requires settings to have actual behavior. The live switch was observed; its persisted value was not changed. |
| `setupWindowDelegate` creates a temporary delegate assigned to a weak property. | Strongly retain the window's delegate for its lifetime. | **Medium; isolated runtime proof.** `App/AppDelegate.swift:207`, close/save callback at `:253`. Drain an autoreleasepool before asserting delegate callbacks, then verify actual Close/Dock reopen and frame/session restoration. |
| “Date Captured” sorts by filesystem creation time. | Rename the existing option “Date Created.” | **Medium; source confirmed.** `Models/ViewerMode.swift:95`, `ViewModels/ImageViewerViewModel.swift:1083`, `Models/ImageFile.swift:60`. True capture-date sorting needs separate incremental EXIF/HEIF metadata work. Copies/imports can change file creation time. |

Grid gesture/button-trait code warrants a real VoiceOver activation test. This review does **not** conclude that SwiftUI fails to synthesize activation. Likewise, a suspected inaccessible-notification issue was rejected: `ContentView.swift:206-209` exposes the full severity/message in the parent combined accessibility label despite hiding its child Text.

### Browsing state and access

**Sort label and collection can disagree.** `ImageViewerViewModel.loadFolderContent` directly assigns the scanner's name-sorted files at `:200-206`, retaining the previous `sortOrder`. The toolbar still displays that prior choice (`StudioToolbar.swift:393-420`). Session restoration stores an index rather than selected file identity and sort (`WindowState.swift:40-41`, `ContentView.swift:332-358`). After sorting Size and selecting the largest file, reopening can restore a different image at the same index. Apply the chosen comparator to every loaded/reconciled snapshot and persist selection by stable file identity. Tests should use files whose size/name order disagree.

**Bookmark cleanup can lose valid recent folders.** `SecurityScopedBookmarkManager.swift:253-263` writes unordered dictionary bookmark values without the corresponding ordered `recentFolders` array. Launch failure cleanup and stale renewal can invoke it. `FolderSelectionViewModel.swift:124-145,231-257` depends on positional pairing, and drops mismatches. The validation reduces wrong-folder opening risk; the supported defect is loss of valid entries/access. Persist ordered URL/bookmark records together and test first/middle/last failed bookmarks and stale renewal.

**Restored write access is narrower than fresh picker access.** `FileSystemService.swift:213-218` and `WindowState.swift:114,178` create read-only security-scoped bookmarks, while Trash needs write access (`ImageViewerViewModel.swift:926-965`). The current failure message already requests folder reselection. Prefer an explicit “Allow changes to this folder…” reauthorization action when Trash needs it; show this requirement before an operation appears to fail unexpectedly. This is source-backed incompatibility, not a signed-app Trash-after-relaunch result. Preserve the app's user-selected read/write entitlement because Trash is a real feature.

**Folder contents do not refresh automatically.** There is no active production caller of `monitorFolder`. That service watches one directory and rescans shallow content (`FileSystemService.swift:158-211`). Add a Refresh Folder command first, then a session-scoped reconciliation watcher. Preserve the selected file and the last known snapshot during disconnection. An access failure must not masquerade as an empty collection.

## Performance and scale

**Unconditional synchronous metadata preparation precedes image loading.** The main-actor viewer calls `prepareImageInsightForCurrentImage` before beginning asynchronous image load (`ImageViewerViewModel.swift:514-577`), including with Insights disabled. The default input provider reads file metadata and parses EXIF/GPS through `ImageMetadataService` synchronously (`AppleIntelligenceInsightsService.swift:29-48`, `ImageMetadataService.swift:166-211`). This confirms blocking I/O on the browsing path; frame-time impact was not profiled. Defer/offload optional metadata, reuse it for a file revision, and keep freshness checks independent of inspector visibility. Profile time-to-next-image with Insights off/on and locally cached/cloud/network-backed images.

**The active Studio thumbnail path bypasses the older bounded thumbnail system.** Grid/Filmstrip use `StudioThumbnailLoader` (`FilmstripView.swift:117-132`), which starts detached decoding per request without shared caching, bounded scheduling, or cancellation propagation. Their task IDs use URL only (`GridPane.swift:114-119`, `FilmstripView.swift:103-110`), so same-path changes do not restart a visible tile's task. Use a shared thumbnail service keyed by file identity, revision, and requested size, with bounded memory and a small measured worker limit. Cancel queued requests when demand disappears. Measure decode counts, cache hit rate, scrolling stalls, and peak decoded bytes before claiming a performance gain.

**Scan cancellation currently rejects publication but does not stop scanning.** The view model cancels/rejects obsolete generations, which protects visible state; the scanner never checks cancellation. Recursive enumeration runs in a DispatchQueue continuation (`FileSystemService.swift:111-155`), and shallow enumeration is synchronous (`:84-108`). The production-code probe returned complete results for already-canceled tasks. Add cancellation checks between entries and an explicit worker cancellation bridge. An individual synchronous disk operation may still finish; cancellation should prevent further enumeration and hold the root grant until the worker exits.

**Repeated scans create new identities.** `ImageFile.swift:6` assigns a random UUID while equality/hash use URL. A repeat scan produced equal values with unequal IDs. Use a stable collection identity before incremental refresh, so selection, scroll position, and thumbnail reuse survive snapshots. Keep identity separate from revision; byte count/mtime or a file-change token should invalidate content without making the same file a new navigation item.

The main-image loader already bounds decode allocation, checks revisions, shares in-flight work, handles memory pressure, and rejects stale completion. Retain it. Large-tree, prolonged-session, thermal, memory-pressure, cloud-placeholder, and external-volume performance still need measurements.

## Image Insights

### Current architecture and fresh evidence

The service attaches oriented, bounded first-frame pixels to a fresh `SystemLanguageModel.default` session, with guided output and separate exact Vision OCR. Image names, camera data, and GPS do not enter its visual prompt. These are real macOS 27 capabilities, and the current implementation uses them already. [Apple multimodal prompting guidance](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting).

The fresh local run used unchanged production service/perception/validator/core/metadata sources, minimal CLI adapters, AFM 3 Core Advanced, and an 8,192-token context. Those five production source hashes match the archived v5 engine. The 30 fixtures were recreated: 21 hashes match the archive, all dimensions/frame counts match, and nine PNGs differ. Original archived pixels are unavailable, so differences cannot be assumed to be encoding-only. This is a current regression smoke, **not** a controlled September-versus-October comparison.

| Observation | Interpretation |
| --- | --- |
| 28/30 returned results; all 14 unchanged repository photos returned results | Normal photographs work; response completion alone does not prove correct image understanding. |
| Adversarial instruction-text screenshot refused | An honest model failure; recognized text should remain independently useful. |
| Authored long receipt failed output validation | Current reliability gap. Invalid prose was not retained, so the exact validation cause is unknown. Fixture differences prevent attribution to an OS/model update. |
| Median 2.78s; range 0.44–17.70s; total 111.61s | Uncontrolled service timings including preprocessing and generation, with cold/outlier requests and concurrent review work. No speed improvement is claimed. |
| All 28 successes contain supplementary detail; 16 contain uncertainty | Instructions saying these fields are normally absent do not consistently suppress filler. |
| Circle/oval and relative-size mistakes; blank-image artistic-intent caveat; table “three items” value claim | Structured output and digit/quote guards do not establish visual truth or semantic grounding. |

The archived v5 evaluation did demonstrate more useful descriptions than the removed category-template baseline, using a small unblinded ordinal review. It remains a regression set rather than a representative accuracy benchmark. Both old and fresh evidence disclose their limits.

### Highest-value improvements

1. **Make OCR an independent result.** OCR completes before generation, but the service returns perception only after the model and validator succeed (`AppleIntelligenceInsightsService.swift:75-100`). The inspector renders text only inside a successful result (`InspectorView.swift:515-607`). Add separate revision-aware OCR state and an explicit Extract text action; publish accepted OCR before model completion and retain it after refusal/timeout/invalid prose. AI-disabled users should still be able to extract text using Vision. Test successful OCR plus failed generation, cancellation, empty text, Vision failure, and rapid navigation.

2. **Keep document descriptions separate from source values.** Prompt guidance forbids rewritten values, but the validator checks digits and certain quotes, not word-form amounts or relationships (`ImageInsightCore.swift:200-205`, `InsightOutputValidator.swift:62-75`). The fresh table still verbalizes a quantity; a source label appears in a sign title. Evaluate a document-specific kind/layout response without OCR fed into descriptive prose. Display extraction independently. Do not try to guarantee semantic truth with a number-word blacklist.

3. **Evaluate text at a resolution suited to documents.** The only OCR input is the same maximum-2,048-pixel image used for scene analysis (`ImagePerceptionService.swift:75-102,153-158`). Low-confidence observations are removed without a coverage notice; only line/character-budget omissions mark truncation (`:48-71`). Test a separately bounded high-resolution or tiled document pass, preserve exact text/positions/confidence, and show explicit no-text/partial-text states. Compare recognition errors, reading order, memory, and cancellation before adopting it.

4. **Remove output that has no user purpose.** The model selects OCR excerpt indices, but the inspector shows full recognized text and never uses selected excerpts (`AppleIntelligenceInsightsService.swift:244-245`, `InsightOutputValidator.swift:35-57`, `InspectorView.swift:534-607`). Remove unused selection generation and evaluate the smaller schema. Tighten detail/uncertainty criteria around whether they change the user's understanding. Version prompt/schema/cache identity together. Quality and latency gains remain hypotheses until paired evaluation.

5. **Profile and evaluate before tuning.** Measure metadata, decode, OCR, budgeting, model loading, first validated result, and cache reuse separately. Try demand-driven prewarming only after measuring cold behavior. Keep unvalidated streamed prose from becoming a copyable final result; showing OCR/progress early already improves perceived responsiveness. Apple's Foundation Models instrument exposes latency and token breakdowns; traces include prompts/responses and should use local public/synthetic fixtures. [Apple performance guidance](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app).

For document structure, evaluate Vision's `RecognizeDocumentsRequest` as a separate extraction path: it exposes words/lines/paragraphs, tables, and lists. Preserve raw recognized text; do not infer cell relationships from plain line order. This is an experiment rather than proof of better StillView output. [Apple document recognition](https://developer.apple.com/documentation/vision/recognizedocumentsrequest), [Apple table-recognition sample](https://developer.apple.com/documentation/vision/recognize-tables-within-a-document).

### Quality acceptance plan

Create a fixed local dataset covering everyday photos, people without identity claims, pets, low light, abstract images, screenshots, receipts/tables, multilingual signs, rotated/tall images, HEIC/RAW, and invalid inputs. Keep the existing regression fixtures. Blind paired prompt comparisons where practical; retain failures and source hashes. Score subject correctness, useful distinct details, unsupported claims, meaningful uncertainty, OCR fidelity/order, completion/refusal, and cold/warm latency separately. Never equate the percentage of successful responses with accuracy. Apple's evaluation guidance supports defining task-specific criteria and testing representative edge cases. [Apple evaluation guidance](https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses).

Suggested release gates: no stale-image/OCR publication, exact preservation of accepted text, no new unsupported document values in the regression set, maintained subject usefulness under blind review, and a measured latency/memory budget. Numerical performance thresholds should follow a baseline on representative Macs; none was invented here.

The confirmed scope is description accuracy and text recognition. Captions/alt text, searchable persisted tags, photography critique, image questions, and comparison remain separate future product directions. Prioritize subject accuracy, unsupported claims, OCR fidelity, and preserving extracted text after model failure in the scorecard. There is no need to introduce cloud inference for these improvements.

## macOS 27 integration and release confidence

- Prefer native scene-focused commands now. A later toolbar/inspector pass can use SwiftUI toolbar items, native overflow/customization and resizable inspectors while retaining the current layout. Local SDK inspection confirms `visibilityPriority` is available on macOS; **`toolbarOverflowMenu` is unavailable on macOS** and should not be proposed from cross-platform examples. Verify any API against the actual SDK before adoption.
- Check the native Info/Insights tab and view-mode semantics with VoiceOver. macOS 27 adds AppKit segmented-control/group semantic roles; use them only where the control is actually tab navigation. [Apple macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes).
- Keep system-adaptive colors, existing Reduce Motion behavior, native Settings, first-frame/orientation behavior, explicit analysis initiation, and the existing cancellation/revision/cache guards. No blanket Observation/Swift language-mode migration is required to optimize this app.
- Repair the scheduled CodeQL architecture/toolchain issue. The [October 5 run](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/37334266922) and [September 28 run](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/36440422798) failed on macro plugin `Bad CPU type in executable` errors before analysis. This is a failed scanner gate, not a validated app vulnerability. The separate grep-based advisory job does not replace completed CodeQL analysis.
- Reconcile active test membership with documented coverage. Add repaired, meaningful window/bookmark/settings/recursive tests through Xcode; do not blindly enable obsolete files or hand-edit the project. Current compiled suites already include access/picker and native Settings synchronization coverage.
- A signed release still needs real sandbox grant/relaunch/Trash checks, VoiceOver, dark/high-contrast/Reduce Motion, external-volume recovery, and archive validation. Unsigned local builds and passing CI do not establish App Store submission or release.

Source inspection found no direct network AI/telemetry client in the inspected production paths. Entitlements declare sandbox, user-selected read/write, and bookmarks; the privacy manifest declares no tracking/collection. Feedback opens user-editable GitHub/email forms and does not automatically send image/OCR content. These are verified source boundaries, not a full security/compliance certification.

## Recursive browsing direction

The file service already has recursive enumeration, but `FolderSelectionViewModel.swift:349` always requests shallow scanning. Merely changing that Boolean would expose package resources, uncancellable all-at-once scans, unstable IDs, and weak partial-error handling. `Models/FolderScanner.swift` is a dormant stub, not the production engine.

The confirmed experience is an explicit **Include subfolders** scope with **All images** across the selected root, relative folder paths to distinguish duplicate names, and a collapsible native folder tree for filtering. Include the tree in the completed feature. Changing the filter should use the existing discovered collection, not reopen a folder picker or run another full scan. Keep Single/Strip/Grid and selected-image Insights intact. The detailed proposal includes policies, state ownership, acceptance tests, and implementation order.

## Evidence and Craft Report

Durable evidence:

- [Fresh AI results and methodology](evidence/2026-10-11/insights-review.md), [raw results](evidence/2026-10-11/insights/current-2026-10-11.jsonl), [environment](evidence/2026-10-11/insights/environment.json), [source hashes](evidence/2026-10-11/insights/current-2026-10-11-source-sha256.txt), [fixture comparison](evidence/2026-10-11/insights/fixture-hash-comparison.json).
- [Folder/scale review](evidence/2026-10-11/folders-review.md), [production-scanner probe](evidence/2026-10-11/folder-probe.swift), [probe output](evidence/2026-10-11/folder-probe-results.txt).
- [Usability review](evidence/2026-10-11/usability-review.md), [verification/privacy review](evidence/2026-10-11/verification-review.md), [window-delegate probe](evidence/2026-10-11/window-delegate-probe.swift), [probe output](evidence/2026-10-11/window-delegate-probe.log).
- [Current CI metadata](evidence/2026-10-11/ci-runs.json), [minimal CodeQL errors](evidence/2026-10-11/codeql-errors.txt).

**Checked:** Current active viewer/inspector/Settings paths; keyboard/menu discovery; source-level accessibility/motion/state behavior; file scanning/access/persistence; decoding/cache boundaries; AI quality/lifecycle/privacy; local validation and hosted CI. The native walkthrough was limited to the states identified above.

**Passed:** Photo-dominant layout, native Settings, understandable disabled Insights state, selectable/copyable metadata, revision-aware main-image/Insights caching, controlled cancellation/stale-publication regressions, current platform compilation.

**Changed:** Review/proposal/evidence documents only.

**Left alone:** Existing visual identity, global developer settings, AI preferences, app/project sources, entitlements, Git history, remote publication. A notification accessibility allegation was rejected after inspecting its combined parent label; live VoiceOver activation and app close/reopen were not established.

**Verdict:** Buildable and useful on macOS 27; finish browsing correctness and independent text extraction before adding a large recursive collection.

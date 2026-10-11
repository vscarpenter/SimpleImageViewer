# StillView macOS 27 implementation verification

Implemented the approved usability, description/OCR and combined recursive browsing proposal on `codex/macos27-usability-recursive-browsing`. Implementation commit: `16641c4`; scanner/bookmark foundation: `4e0fd14`; approved plan/spec record: `21426b5`. Version remains 5.0.0, build 44. These are local commits; no push, hosted CI or release publication occurred.

## Delivered behavior

- Retained main-window delegate, focused File/View/Image commands, one native View menu, filename overlay and image context menu. Creation-time sorting is labeled Date Created. Grid navigation uses actual rows/columns, a selected/focus outline, and Return opens the selected image. Native text editing keeps its shortcuts. Reduced Motion covers stage arrows.
- Separate, manual Vision extraction remains available with AI descriptions disabled or unavailable. Accepted OCR is published before generation, survives a description failure, and has its own refresh/cancel/error/copy states. Revision and navigation guards reject stale results. Text remains as recognized, including repetitions, with honest incomplete-text notices.
- Descriptions use a concise title/summary. Substantial documents receive bounded broad captions, avoiding invented values, counts and row relationships. Eligible tall/dense sources receive a separate maximum-4096 OCR pass while the scene attachment remains maximum-2048. No background collection-wide analysis is introduced.
- Include Subfolders explicitly changes the selected folder's scope. All images combines supported regular files across ordinary descendants. The native collapsible tree filters a branch and its descendants; filename/relative-path search filters the discovered collection. Recursive grid captions distinguish duplicate filenames. Scope, sort, filter, sidebar visibility and selected path survive saved sessions.
- Discovery streams bounded batches on a worker, excludes hidden files, packages, symlinks and aliases, distinguishes child issues from root failure, and retains an incomplete usable snapshot on cancel. Refresh Folder reconciles changes and preserves visible selected identity. Automatic recursive watching is deferred.
- Sorting/filtering/subtree counts run on a serial worker with cancellation and generation checks. Latest user navigation survives incoming batches. Successful Trash invalidates pre-deletion projections. Recent folder URLs and grants are stored together and migrated without shifted associations, including moved-root resolution.
- A shared thumbnail pipeline limits cache count/decoded bytes, actual decode workers and queued demand. Requests deduplicate, cancel independently and invalidate by revision and pixel size. ImageIO first-frame/EXIF behavior has real-pixel regressions. File workers retain an additional original-root grant until actual worker exit, including canceled decode/OCR work.

## Completed verification

On a Mac mini running macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), macOS SDK 27 and arm64:

| Check | Result |
| --- | --- |
| Final app-hosted Release tests | 300 passed, 0 failed, 0 skipped |
| Release arm64 build | Passed with signing disabled |
| SwiftLint | 0 errors; existing PreferencesViewModel complexity warning only |
| Toolchain check | Passed |
| Test membership check | 15 active sources verified; 56 additional on-disk sources remain outside the target |
| Whitespace check | Implementation changes passed; frozen evaluation snapshots preserve existing source whitespace for byte-exact hashes |
| Local Run entrypoint | Executable; shell syntax/flag checks passed; GUI modes were not exercised |
| AI fixed corpus | Actual on-device inference completed 30/30; evaluated production sources match the repository |
| Evidence hashes | All bundled artifact hashes verified |
| Local sandbox artifact | Ad hoc signature verifies strictly with the existing three sandbox/folder entitlements |

The final result bundle is `/tmp/stillview-implementation-release-tests-2026-10-11.xcresult`; build/test/lint logs are alongside it under `/tmp/stillview-implementation-…-2026-10-11.log`. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` was used for the installed Xcode and SourceKit. AppIntents metadata extraction reports the existing no-framework warning. No Xcode project file was hand-edited.

Regression evidence covers cancellation and stale publication, scanner traversal, bookmark associations, window-state migration, path restoration/user overrides, row navigation, refresh revision changes, deletion while filtered and while projection is pending, thumbnail pixels/capacity/cancellation, original-root worker grant ownership, independent OCR before/following model failure, and stale/canceled OCR. Initial failures and the caption RED/GREEN probe are documented in the [plan](../plans/2026-10-11-macos27-usability-and-browsing.md) and [AI evidence](../evaluations/2026-10-11-ai-ocr/README.md). Grant-count tests inject successful starts/stops; they prove ownership/lifetime, not real provider authorization.

## Accuracy and measured scale

The [independent final AI comparison](../evaluations/2026-10-11-ai-ocr/final-v10-comparison.md) distinguishes completion, delivery and recognition. OCR delivered 150/154 expected token occurrences versus the baseline's 62/154, primarily because completed recognition now survives two old description failures. Recognition on the eight historically observable paired cases stays 62/66. All 14 photo subjects remain represented; concise descriptions still contain some geometry/background errors. General photo-description accuracy improvement is unproven.

A separate tall synthetic document improved from 483 to 508/724 exact token occurrences and 29 to 40/91 exact lines at the 4096 bound. Approximately four times the RGBA-equivalent decoded pixel bytes were needed. Many recognition errors remain; this is one fixed-fixture gain, not a general accuracy or speed claim.

Scanner measurements use local APFS synthetic hard-link entries, metadata only, without retaining the collection or decoding images:

| Entries | First image batch | Enumeration total | Scanner peak resident memory |
| ---: | ---: | ---: | ---: |
| 1,000 | 6.45 ms | 68.34 ms | 13.50 MB |
| 10,000 | 7.33 ms | 692.69 ms | 13.60 MB |
| 100,000 | 6.91 ms | 6,474.26 ms | 13.68 MB |

Every record was returned; batches contain at most 64 combined records. Consumer cancellation returned in 0.048–0.060 ms after the first batch. That is cooperative cancellation on this local fixture, not a bound on a blocked provider worker's exit. Workers retain their grant through actual exit.

Separate Release app-hosted projection measurements supply one full synthetic snapshot per size with an injected lifecycle loader and a 5 ms main-queue heartbeat:

| Image records | Projection elapsed | Maximum observed heartbeat gap |
| ---: | ---: | ---: |
| 1,000 | 55.42 ms | 5.65 ms |
| 10,000 | 475.54 ms | 5.60 ms |
| 100,000 | 4,467.01 ms | 5.89 ms |

The main queue remained schedulable during computation. The 100k projection still takes several seconds. These are controlled single-snapshot measurements, not full SwiftUI rendering, incremental-pipeline memory, thumbnail hit-rate or real provider benchmarks. Filtering/counting have cancellation checkpoints; a synchronous sort finishes before its next cancellation check. See [raw scanner measurements](evidence/2026-10-11/implementation-scanner-scale.jsonl) and [validation data](evidence/2026-10-11/implementation-validation.json).

## Native and sandbox verification status

The unsigned development walkthrough verified the native CmdO picker, direct collection (1), combined recursive collection (5), three distinct duplicate leaf names with relative captions, native tree expansion, Travel (3)/Italy (2) branch filters, filename search with CmdA editing, one View menu and the visible Including subfolders label. It found folder/grid focus and empty-to-nonempty search focus problems; source fixes are included in the final built/tested implementation.

The Mac locked before the final native pass. Manual unlock was requested. Rechecking those focus fixes, OCR completion/copy, and real sandboxed selected-folder access/relaunch is pending. The signed verification artifact is `/tmp/stillview-sandbox-verification-2026-10-11/StillView - Simple Image Viewer.app`; signature inspection is [recorded separately](evidence/2026-10-11/implementation-sandbox-signature.txt). A valid ad hoc signature with App Sandbox enabled does not establish runtime access, distribution signing or notarization.

No live VoiceOver session, system appearance changes, external drive, cloud placeholder or SMB validation was performed. These remain explicit validation boundaries. URL identity/revision uses standardized paths plus size/modification date: rename continuity and same-size edits preserving dates are outside the contract. The [independent source integration review](evidence/2026-10-11/implementation-integration-review.md) found no remaining reproduced source defect after its follow-up corrections.

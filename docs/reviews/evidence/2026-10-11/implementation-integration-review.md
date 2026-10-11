# Implementation integration review

Reviewed October 11, 2026 against the approved [recursive browsing proposal](../../../specs/2026-10-11-recursive-folder-browsing-proposal.md), from the current working tree over `4e0fd14`. The initial independent pass inspected source, the implementation diff, and the completed implementation test log without running builds, tests, model inference, or native UI automation. After the parent reproduced a native quit/relaunch failure, this reviewer implemented the authorized lifecycle corrections below and ran focused app-hosted regression tests. Native UI evidence and full-suite validation remain in the parent implementation verification record.

## Findings resolved during review

| Reproduction case | Verified source correction |
| --- | --- |
| Cancel a scan, then select another root while the canceled cursor is still exiting. | `FolderSelectionViewModel.cancelScanning()` retains the draining task, and the replacement waits for its completion before replacing the root grant. |
| Close the inspector or switch to Info while an explicit Analyze/Extract Text action is waiting for input preparation. | Root cancellation methods cancel `insightInputTask` as well as the downstream description/OCR task. Publication checks reject canceled input work. |
| Restore a large recursive session, interact with its sort/filter/selection, then receive another scan batch. | `ContentView` applies restored UI/path once and checks that the snapshot belongs to the saved root. Picker actions clear restoration intent. |
| Explicitly navigate, search, filter, or sort before the restored target arrives in a later batch. | Those user actions clear the pending restored image path. The pending path remains available for persistence until resolved or superseded. |
| Open a folder whose scanner accumulates records in a dictionary. | Production enables asynchronous browsing. Initial selection is made from the deterministically sorted projection rather than the dictionary snapshot's initial identity. Picker publication no longer sorts on the main actor. |
| Disable Include Subfolders while a descendant branch is selected. | `ImageViewerViewModel.loadFolderContent()` clears the incompatible folder filter when scope becomes shallow. |
| Start Trash, filter the target out before recycling finishes, then clear the filter. | Trash completion removes the identity from the discovered collection even if it is absent from the visible projection, and preserves the newer visible selection. |
| Return to Folder Selection during description/OCR work. | The return action explicitly cancels preparation, description, and OCR work before hiding the viewer. |
| Replace a root while canceled image, thumbnail, Info metadata, or perception work is still exiting. | `SecurityScopedResourceLease` captures the original granted root and owns an additional balanced grant. Image-loader work records, thumbnail jobs and worker closures, Info metadata closures, and perception decode/Vision closures retain it through actual exit, including canceled workers. |
| Publish a large collection while navigation or a newer root/filter request changes. | Production filtering, sorting, and subtree counts execute on one serial worker. Generation checks reject superseded projections; publication reads the latest selected identity. Filtering/count loops check cancellation. |
| Count the root subtree when root URLs differ only in directory spelling. | Root counts normalize by path components and store the result under the current root's URL key. |
| Recycle an image while a projection still holds the pre-Trash collection. | Trash reconciliation cancels and invalidates the previous projection, removes the discovered identity, and schedules a new projection/count update from the updated collection. An active 10k regression covers this interaction. |
| Select a subsequently removed file in the retained snapshot while refresh projection is running. | Same-root batch reconciliation uses the current index at publication for the missing-selection fallback. Explicit filter/search fallback to the first result remains separate. |
| Replace a root while expected-image-size metadata work is still exiting. | The default metadata reader acquires the original-root worker lease before enqueueing, captures it in the detached worker, and retains it through actual worker exit. |
| Open a collection through the native picker, quit, and relaunch into Folder Selection with all collection state lost. | `SimpleImageViewerApp` supplies its adaptor-owned `WindowStateManager` directly to `ContentView`. All three global delegate casts were removed. The app-hosted runtime probe confirms that `NSApplication.shared.delegate` is `SwiftUI.AppDelegate` and the former cast to the app's `AppDelegate` returns false. |
| A window autosave fires before restored discovery publishes its first folder. | `WindowStateManager` preserves the loaded folder bookmark/path, numeric index, recursive scope, filter, query, and selected identity until an actual folder handoff or explicit clear. Saving also captures the live view model's root and current index synchronously. |
| Quit before a deferred save or queued current-index observer executes. | One synchronous `AppDelegate.applicationWillTerminate` callback captures and writes state before returning. Both deferred termination observers were removed, and immediate save cancels the pending debounce timer. |

The review also checked component-based folder filtering, deterministic path tie-breaks, same-root selection preservation, revision-triggered image reloads, partial collection retention on cancellation, root-checked restoration, and temporary lease balancing during window-state bookmark validation.

The asynchronous projection follow-up corrections above were reread after implementation. No outstanding concrete source finding remains from this independent integration pass. Final tests and native verification remain the implementation owner's responsibility and are recorded separately.

## Remaining validation boundaries

- Source inspection and injected grant tests establish additional original-root lifetime ownership for loader, thumbnail, Info metadata, and perception workers; expected-size metadata uses the same lifetime pattern. Real signed-sandbox relaunch/provider authorization remains separate validation; no such proof was performed in this independent pass.
- Stable identity is a standardized URL, with size/date revision checks. Rename continuity and same-size edits preserving modification dates remain outside that identity/revision contract.
- Native tree/grid accessibility, provider hydration/disconnection, external volumes, SMB, and signed relaunch authorization require native/provider evidence. Source inspection alone does not establish them.
- Automatic root-tree monitoring is deferred; Refresh Folder provides reconciliation in this delivery.

## Recorded projection measurement

The completed intermediate checkpoint `/tmp/stillview-implementation-tests-verified-2026-10-11.log` reports 296 app-hosted tests with zero failures. This checkpoint precedes the last follow-up source corrections and is not a claim that the final source has already completed its rerun. The source of `test_asyncProjection_reportsLargeCollectionAndAllowsMainQueueHeartbeat` supplies one full synthetic snapshot at each scale, uses an injected lifecycle image loader, and schedules a main-queue timer every 5 ms. The logged measurements are:

| Synthetic records | Projection elapsed | Maximum observed heartbeat gap |
| ---: | ---: | ---: |
| 1,000 | 52.70 ms | 6.21 ms |
| 10,000 | 480.62 ms | 6.21 ms |
| 100,000 | 4,724.59 ms | 6.22 ms |

These are controlled Debug app-hosted synthetic projection observations, not full SwiftUI rendering, real filesystem enumeration, thumbnail decoding, signed-sandbox/provider behavior, or a general latency guarantee. The 100k projection still takes several seconds to finish; the observed heartbeat indicates that the main queue remained schedulable during that computation. The test does not enforce a maximum heartbeat threshold. Canceled filtering/count passes have checkpoints, while an in-progress synchronous sort finishes before its following cancellation check.

## Further scale measurement approach

Extend the controlled measurement to a Release build and 64-entry incremental scan batches, then representative actual image folders. Time first usable publication, every incremental projection, final projection, filename/path filter changes, sort changes, and cancellation. Run a periodic main-queue heartbeat alongside discovery and record its maximum delay. Include folder depth and duplicate leaf names. Report scanner, projection, and rendering time separately, plus real thumbnail/cache memory behavior. Coalescing pending snapshots and incrementally maintaining counts/sorted records can be evaluated if measured completion latency remains material.

## Implementation checkpoint before native follow-up

The parent verification subsequently completed Release app-hosted tests (300 passed, zero failures/skips), a Release arm64 build, toolchain/test-membership checks and lint. Its controlled Release projection measurements were 55.42/475.54/4467.01 ms for 1k/10k/100k records, with observed main heartbeat gaps 5.65/5.60/5.89 ms. These are historical measurements from the 300-test checkpoint, before the lifecycle follow-up; this independent source reviewer did not execute those checks. The parent verification now records the final 307-test run separately. See the [parent verification record](../../2026-10-11-macos27-implementation-verification.md) for native and signed-sandbox status.

## Native restoration follow-up

The parent's signed Release quit/relaunch checks reproduced a missing collection restoration even after a clean, long-lived recursive browsing session. Source tracing identified disconnected view-model/folder tracking through SwiftUI's delegate bridge, early autosave clearing loaded state, and asynchronous termination persistence. The authorized correction covers those three paths; it does not add an arbitrary launch delay or acquire the saved root early merely to initialize tracking.

This reviewer ran the active `ApplicationPersistenceRegressionTests` suite before implementation: the runtime probe passed, while the three behavior tests failed with 12 assertions. The resulting log is `/tmp/stillview-native-lifecycle-red-2026-10-11.log`. After correction, the final focused run passed all four lifecycle tests and six existing viewport/window/command tests (10 tests, zero failures), recorded in `/tmp/stillview-native-lifecycle-verified-2026-10-11.log` and its `.xcresult`. `git diff --check` was clean. These are focused Debug app-hosted results.

The parent then completed the required rebuilt signed Release checks: immediate quit restored Grid, Size sort, recursive scope, Italy filter, query and receipt identity; a subsequent normal relaunch on the final binary restored the session and read 47 OCR lines from the descendant without a picker. The full app-hosted Release suite passed 307 tests, zero failures/skips, including the four lifecycle checks and three new active startup-bookmark regressions. Startup grants are retained through resolution/access/availability failures, with balanced temporary preflight scope. The subsequent settings copy-only clarification passed Release build, lint and native inspection. These are parent-reported artifacts, not checks executed by this independent reviewer. See the [native record](implementation-native-verification.md) and [full test summary](implementation-final-test-summary.json); provider and VoiceOver boundaries remain explicit.

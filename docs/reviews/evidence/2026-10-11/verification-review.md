# StillView verification, platform, and privacy review — 2026-10-11

Read-only review of current repository at `/Users/vinnycarpenter/Projects/SimpleImageViewer`, HEAD `9da3f3fe853febdb47828654de7f348072c25e98` (5.0.0/build 44). No repository changes or cloud security scan. Root agent owns full local build/tests/live UI and reports 229 tests passed from these 15 source files, Release arm64 build passed, lint has one complexity warning. A skipped metadata extraction build-tool warning is not a compilation failure. This pass ran the test-target audit script, inspected source/configuration, read current GitHub Actions results, and used an isolated AppKit delegate-lifetime probe.

## Confirmed issues

### P2: NSWindowDelegate does not survive the autorelease pool

`StillView - Simple Image Viewer/App/AppDelegate.swift:207-210` creates a local `WindowDelegate` then assigns the weak `NSWindow.delegate`; no strong reference to the delegate exists. After the enclosing autorelease pool drains, callbacks such as `windowShouldClose` (same file:253) and move/resize delegate callbacks disappear. The app's intended close behavior is to save state and hide its existing window. Losing the callback allows the ordinary close path and bypasses this explicit save/hide. Dock reopening may still be recovered through SwiftUI; do not claim irreversible inability to reopen without the root's live evidence.

The older `AppDelegateTests.swift` and `WindowManagementIntegrationTests.swift` exist on disk but are not test-target members. Their immediate delegate assertions could also pass before the pool drains.

Isolated verification on this macOS 27 host (no app source compiled/modified). Saved probe: `/tmp/stillview-window-delegate-probe-2026-10-11.swift`; output: `/tmp/stillview-window-delegate-probe-2026-10-11.log`. Actual production close/reopen was not reproduced in this pass:


```swift
import AppKit
final class ProbeDelegate: NSObject, NSWindowDelegate {
    deinit { print("delegate deinitialized") }
}
weak var weakDelegate: ProbeDelegate?
let window = NSWindow()
func attach() {
    autoreleasepool {
        let temporary = ProbeDelegate()
        weakDelegate = temporary
        window.delegate = temporary
        print("inside helper delegate present:", window.delegate != nil)
    }
}
attach()
print("after autoreleasepool weak delegate present:", weakDelegate != nil)
RunLoop.current.run(until: Date().addingTimeInterval(0.01))
print("after runloop weak delegate present:", weakDelegate != nil)
print("after runloop window delegate present:", window.delegate != nil)
```

Output: inside helper `true`; delegate deinitialized; after pool weak delegate `false`; after runloop weak delegate `false`, window delegate `false`. A first probe without an explicit autorelease pool appeared to retain the delegate, so it is deliberately superseded by this evidence.

Recommendation: strongly retain the delegate for the window's lifetime; add a regression that drains an autorelease pool before testing actual close/reopen/save behavior.

### P2: Failed/stale bookmark cleanup corrupts the recent-folder/bookmark pairing

`StillView - Simple Image Viewer/Services/SecurityScopedBookmarkManager.swift:253-263` persists `Array(activeBookmarks.values)` into `folderBookmarks` without also persisting the corresponding ordered URLs in `recentFolders`. Dictionary iteration order is unrelated to the original recent-folder order; a failure also shortens the bookmarks array. This function runs at launch whenever any restoration fails (:386-389), and stale bookmark renewal reaches it through `createBookmark` (:117, :175).

`StillView - Simple Image Viewer/ViewModels/FolderSelectionViewModel.swift:124-145` and :222-257 rely on matching positional arrays. Its validity check at :236 rejects a bookmark resolving to a different folder, then saves only surviving pairs. Thus a moved/deleted/unresolvable recent folder can cause otherwise valid recent entries and their saved access to disappear after startup cleanup. The equality check limits the risk of silently opening the wrong folder, so the supported claim is loss of valid recent entries/access.

Recommendation: persist one ordered record per folder containing URL/bookmark together; migrate the existing parallel arrays; test failure of the first/middle/last of several bookmarks and stale renewal while preserving all surviving associations.

### P2 usability flaw: Persistent bookmarks retain read-only authority while Trash requires write authority

`StillView - Simple Image Viewer/Services/FileSystemService.swift:213-218` creates bookmarks with `.securityScopeAllowOnlyReadAccess`. `Models/WindowState.swift:113` and :174 do the same for session restoration. `ImageViewerViewModel.swift:926-965` supports Move to Trash and requests write access at runtime; its failure message at :955 already instructs the user to reselect the folder. After a fresh process opens the folder through only its saved read-only grant, the entitlement alone cannot upgrade that grant to write access. This is source-backed permission incompatibility; actual signed-app Trash-after-relaunch was not performed in this pass.

Recommendation: make write reauthorization an intentional inline action for Trash, or persist the user-selected write grant if that is the product policy. Preserve user-selected read/write entitlement because the real app supports Trash; reducing it to read-only would break an existing action.

## Verification gaps and architectural risks

### P2: Tests on disk overstate the executable suite

There are 71 `.swift` files under `StillView - Simple Image Viewer Tests/`, but only 15 explicit sources in the target's `PBXSourcesBuildPhase` (`StillView - Simple Image Viewer.xcodeproj/project.pbxproj:730-750`). There is no synchronized folder automatically adding the rest. `python3 scripts/check-test-target.py` passes, reporting 15 sources and protecting 14 named regression files. This is correct for the required regression subset, not proof that all test files execute.

Meaningful exclusions include `AppDelegateTests.swift`, `WindowManagementIntegrationTests.swift`, `WindowStateManagerTests.swift`, `PreferencesServiceTests.swift`, `PreferencesPersistenceTests.swift`, `PreferencesValidatorTests.swift`, `PreferencesViewModelTests.swift`, `ShortcutsViewModelTests.swift`, `InsightEvalHarnessTests.swift`, and broader accessibility/UI suites. `README.md:532` and :546-580 describe a comprehensive suite and name excluded files as coverage.

Important qualification: compiled `FileSystemServiceTests.swift` includes path-boundary/security alias and folder-picker lifecycle regressions (:293 onward); compiled `ViewingLifecycleRegressionTests.swift` includes three native Settings-pane synchronization tests (:544 onward). Do not say access/Settings are entirely untested. Many excluded files target old APIs; audit/repair or replace them before adding target membership rather than blindly enabling stale suites.

Recommended active tests: actual close/Dock reopen/quit and frame/session persistence after runloop drains; bookmark association/migration and actual sandbox read/write authorization; Settings change persistence across app reconstruction; recursive scan cancellation, hidden/package policy, aliases/symlinks escaping root, inaccessible subfolders, duplicate leaf filenames, scan with many images, partial errors and progress.

### P1 verification gap: Current scheduled CodeQL pipeline is failing before analysis

Latest two scheduled CodeQL runs (2026-10-05 and 2026-09-28) on the same current HEAD failed. The October 5 run's Build (CodeQL) failed with Swift macro compiler-plugin `Bad CPU type in executable` errors for SwiftUI `@State`, previews and FoundationModels generated types, and Perform CodeQL Analysis was skipped. This is a CI/extraction/toolchain failure, not a validated app security vulnerability.

Read via authenticated read-only GitHub CLI `gh run list/view`. Every cited run targets current revision `9da3f3fe853febdb47828654de7f348072c25e98`. Compact metadata is saved to `/tmp/stillview-ci-evidence-2026-10-11.json`; three compiler errors are saved to `/tmp/stillview-codeql-error-evidence-2026-10-11.txt`, with no token/environment sections or full logs.

Current evidence: [October 5 CodeQL run](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/37334266922); [September 28 run](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/36440422798). The latest Build and Test and plain CI runs at this HEAD (2026-09-15) succeeded, including Release archive/export job: [Build and Test run](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/35016731608), [CI run](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/35016731598). Do not call all current CI green from those older green runs.

Recommendation: investigate/pin compatible CodeQL/toolchain architecture and obtain a fresh complete analysis. `.github/workflows/build.yml:130-159`'s grep-based security job is advisory, always prints completion and `continue-on-error: true`; it is no substitute for a completed scanner. Source uses no direct network AI/telemetry client in the inspected app.

### Distribution proof is narrower than a released product

CI builds with signing disabled (`.github/workflows/build.yml:177-187`) and exports artifacts (:190-216). The latest job actually succeeded; do not claim its exporter is broken merely because signing is disabled. An exported CI artifact does not by itself prove App Store signing/provisioning, notarization/Gatekeeper success, sandbox operation under production signing, App Store upload/review, or live-store release. `Documentation/AppStoreSubmission.md:3` accurately says these remain to be verified. Root's current local build will be separate evidence.

Recommendation: validate the intended signed release archive's identity/entitlements and real sandbox grant/relaunch/Trash behavior; use App Store Connect/current store metadata as release proof when submission is authorized.

## Correct foundations to retain

- Project and all target deployment configurations are macOS 27.0, Release 5.0.0/build 44, Apple silicon. SDK is macosx; Swift language mode is 5.0 (language-mode choice is not a bug or evidence of an old compiler).
- `scripts/check-macos-toolchain.sh` verifies host macOS/Xcode/SDK major >=27 and native arm64. Workflows use `xcode-27`, which is currently valid. Official GitHub documentation confirms macOS 27 arm64/Xcode 27 host availability: [September 10 changelog](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/), [runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).
- App Sandbox, user-selected read/write and app-scope bookmarks are declared (`Simple_Image_Viewer.entitlements:5-10`); no network-client entitlement is declared. Write permission is justified by the existing Trash action.
- `PrivacyInfo.xcprivacy` declares no tracking or collected data plus FileTimestamp/UserDefaults/SystemBootTime required reasons. This is source configuration, not a complete privacy compliance audit.
- Logger info/debug/status calls are DEBUG-only (`Extensions/Logger.swift:38-53`), and release warning/error messages are private-redacted (:56-67). No release logging leak found in this source pass. DEBUG logs can contain selected paths, so diagnostics sharing should remain user-controlled.
- `FeedbackService.swift:89-104` collects app/build/macOS version, fixed Apple Silicon architecture, and AI enabled setting. GitHub and email feedback open user-editable forms through NSWorkspace (:40-63); they do not automatically submit, include image contents, filenames, paths, OCR or prompts. System fields in a GitHub URL leave the app when the user chooses feedback; the current behavior is reasonable, not an undisclosed image upload.
- Insights evaluation harness is under `#if DEBUG`, writes local temporary Markdown reports, and prints only progress counters (`InsightEvalHarness.swift:1`, :59-70). It does not ship as a release bulk-analysis feature.

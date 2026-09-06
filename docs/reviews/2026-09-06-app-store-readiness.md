# StillView 4.5.1 App Store readiness review

## Follow-up: approved fixes completed September 6, 2026

**Items 2–5 are implemented and locally verified. Item 1 is complete in the app; both policy pages are published, with factual copy corrections still pending.** Version stays **4.5.1 (35)** on `codex/app-store-readiness-fixes`. The original review below is preserved as a historical snapshot, not a list of still-open code findings.

| Item | Completed change | Verification |
| --- | --- | --- |
| 1. Privacy | About and Help link to `https://stillviewapp.com/privacy.html`; timestamp manifest includes C617.1, 3B52.1, and DDA9.1; supported NSWorkspace accessibility properties replace reads of system UserDefaults. | About's native accessibility tree exposes the exact policy URL and browser hint. The built manifest matches source; no entitlement changes. Privacy and Terms both returned HTTPS 200 on September 6. Publication is verified; copy alignment and App Store Connect fields remain pending. |
| 2. Folder and keyboard routing | One persistent picker serves welcome, Cmd+O, toolbar, and restoration. Failed/canceled requests preserve the active collection and scope. Back stops the slideshow. Viewer shortcuts respect both SwiftUI and AppKit focus, and clicking the canvas restores viewer focus. | First Cmd+O from a loaded viewer opens the picker; Cancel preserves the same photo; B returns to welcome; Delete/S/Return do not affect hidden images. Tab-focused Grid retains Space, Tab-focused Strip activates on Space without changing selection, and clicking the canvas restores Right-arrow navigation. |
| 3. Trash | Capture file/folder before confirmation, retain scope through completion, prevent duplicates, and reconcile by URL while preserving newer selections and collections. | Twelve controlled-service regressions cover selection, sort, folder/clear changes, scope lifetime, failure, cancellation, duplicates, and last-image slideshow cleanup. No user image was deleted during validation. Actual distribution-signed recycling remains a release smoke check. |
| 4. Compact toolbar | Independent layout regions, adaptive overflow, explicit mode labels, and consistent 800-point minimum width. | Native Single/Strip/Grid inspection at 800 points and a wide window. Grid no longer overlaps; More actions contains slideshow/interval, Share, Trash, and sorting. Date Modified remains accessible through the submenu. |
| 5. Truthful Settings and copy | Removed inactive settings and fake previews; shortcuts are a searchable built-in reference. Working startup settings are labeled accordingly. Help, README, submission/reviewer notes, keyboard reference, and bundled notes match current raster formats, static first-frame behavior, macOS 26+, Insights, and confirmed Trash behavior. | Native General/Appearance/Shortcuts inspection and shortcut search. Generated two-frame GIF proves first-frame display; vector scans are excluded. Normal local Insights generation succeeded on the sample canyon image. |

### Final local evidence

- **223 tests passed, zero failures**: [test log](/private/tmp/stillview-readiness-fixes/complete-tests.log), [result bundle](/private/tmp/stillview-readiness-fixes/complete-tests.xcresult). This adds 35 active regressions to the 188-test baseline. The membership guard still verifies 16 active test source files; legacy inactive suites were not silently claimed as coverage.
- **Fresh universal Release build passed** with arm64 and x86_64: [build log](/private/tmp/stillview-readiness-fixes/final-release.log). The built Info.plist reports the correct bundle ID, 4.5.1 (35), and macOS 26.0 minimum; all eight bundled release-note items are present.
- **SwiftLint passed with five pre-existing warnings and zero serious violations**: [lint log](/private/tmp/stillview-readiness-fixes/complete-lint.log). The removed Preferences preview code eliminated the previous file-length warning. Whitespace, JSON, manifest, and test-membership checks passed.
- Native checks used `/private/tmp/stillview-readiness-fixes/ReleaseDerivedData/Build/Products/Release/StillView - Simple Image Viewer.app`, locally ad-hoc signed with the app's declared sandbox/read-write/bookmark entitlements. Signature verification passed. This is not distribution signing or Organizer validation.
- Independent source review found two additional folder cases: duplicate expired-bookmark error UI and a late scan replacing a newer failed request. Both were reproduced by failing tests, repaired, and passed. Native testing caught SwiftUI focus not exposed through the original AppKit-only probe; explicit focused values plus a focusable canvas fixed the reproduced Tab/Space failure.
- Local commits separate privacy/formats (`53807f7`), viewer behavior/layout (`68d17af`), and Settings/release documentation. The plan was committed as `777aff4`. No Xcode project file was edited, and pre-existing untracked workspace material was preserved.

### Public policy update

The app owner published [Privacy](https://stillviewapp.com/privacy.html) and [Terms](https://stillviewapp.com/terms.html). Both returned HTTP/2 200 over HTTPS on September 6, 2026. The publication requirement is closed. A source comparison found four copy corrections covering removed Settings, explicit sharing, GitHub draft transmission, and the role of Foundation Models. Suggested wording and evidence are in the [copy review](2026-09-06-live-policy-copy.md). The website was not edited by this task.

### Remaining release gates

1. Apply the [live policy copy corrections](2026-09-06-live-policy-copy.md), recheck both published pages, and use `https://stillviewapp.com/privacy.html` in App Store Connect.
2. Validate the final distribution-signed archive, run its release smoke checks (including a disposable-image Trash/recovery check), and confirm the selected processed build, metadata, screenshots, privacy answers, and review notes in App Store Connect.
3. Push/integrate the intended release branch and verify CI on that exact commit before submission. No push, PR merge, upload, or submission was performed in this follow-up.

The broader backlog and coverage limits recorded in the initial review remain outside these five approved repair groups. Full VoiceOver and dark/high-contrast walkthroughs, long-session performance, and external-volume recovery were not established by this pass. Runtime checks reused the existing sample-photo recent entry and changed the window size and last-viewed Preferences tab; original recent folders and images were preserved.

---

## Original review before implementation


Reviewed September 6, 2026, at `448cd7e549c22c3c7b85f16c4519381498f503cc` on `codex/viewing-and-insights-correctness`, version **4.5.1 (35)**.

**Verdict: hold submission.** The recent viewing and Insights repairs pass local verification, but privacy disclosures, navigation, Trash reconciliation, compact layout, and misleading feature/settings descriptions still need work. This review changed no application source or Xcode configuration and did not publish, push, merge, or submit a build.

## Verification completed

| Gate | Current evidence |
| --- | --- |
| Release build | **Passed**, Xcode 26.6 / macOS 26.5 SDK. Built binary contains **arm64 and x86_64** slices. Generated Info.plist reports 4.5.1, build 35, macOS minimum 26.0, photography category, and non-exempt encryption false. |
| Active test suite | **188 tests passed, zero failures.** The membership check verifies 16 app-hosted test source files. There are 72 Swift test files on disk; this is not coverage of every legacy suite. |
| SwiftLint | **Six warnings, zero serious violations** across 96 production Swift files. Existing warnings concern four legacy SwiftUI aspect-ratio calls, PreferencesViewModel complexity, and PreferencesTabView length. There is also a configuration warning for the disabled line-length rule. |
| Runtime | Launched the newly built Release app after applying a local ad-hoc signature with its declared entitlements. Verified the running executable's path and embedded sandbox, user-selected read-write, and app-scope bookmark entitlements. This is development validation, not an App Store distribution signature. |
| Visual walkthrough | Light appearance: welcome, What's New, Single, Strip, Grid, Info, Insights, fullscreen entry/exit, wide and compact windows, and the 800-point minimum width. Used the repository's 14 sample photos. Generated the current Alley insight locally and observed it retained across browsing surfaces. |
| Format probes | A separate Swift probe using the production ImageDecoder reproduced the SVG/GIF limitations below; the current supported-type predicate excludes PDF. |
| Repository | Whitespace check passed. Existing untracked `.agents/`, `.machinist/runs/`, `skills-lock.json`, and `tasks/` were preserved. Only this report was added. |

Build evidence: [Release log](/private/tmp/stillview-release-review-20260906/build-retry.log), [test log](/private/tmp/stillview-release-review-20260906/tests.log), [XCTest result bundle](/private/tmp/stillview-release-review-20260906/tests.xcresult), [lint log](/private/tmp/stillview-release-review-20260906/lint.log), [format probe](/private/tmp/stillview-functional-format-probe.swift).

The first sandboxed build failed because Xcode's compiler macro plugins could not launch; the authorized retry outside the tool sandbox succeeded. This was an execution-environment failure, not an app compilation defect.

## Highest-priority open items

P1 identifies a pre-submission compliance repair. P2 identifies a concrete behavior defect to repair for this release. P3 is lower-impact polish. Runtime observations and source/probe evidence are distinguished below.

### 1. P1 — Align privacy policy access and required-reason declarations

**No clearly labeled privacy-policy link exists in the app.** About links to the author and repository, and Help offers privacy prose, but no Swift source provides a policy link. [AboutView.swift:90](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/AboutView.swift:90>). Apple requires a privacy-policy link in both the app and App Store Connect. Add an accessible Privacy Policy action in About or Help and use the same verified policy in the listing. [App Review guideline 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#privacy).

**The timestamp reason does not cover the app's main use.** [PrivacyInfo.xcprivacy:18](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/PrivacyInfo.xcprivacy:18>) declares only `C617.1`, while [ImageFile.swift:63](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Models/ImageFile.swift:63>) reads dates from user-selected images for sorting, revision checks, and display. Add the applicable user-granted-file reason `3B52.1` and timestamp-display reason `DDA9.1`; retain `C617.1` for container-file operations. Apple's definitions distinguish these uses. [Required-reason API categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

**System accessibility preferences are read through app UserDefaults.** [AccessibilityService.swift:87](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Services/AccessibilityService.swift:87>) and [line 216](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Services/AccessibilityService.swift:216>) read ReduceTransparency, AppleAquaColorVariant, and DifferentiateWithoutColor. The declared `CA92.1` covers the app's own defaults, not intentional reads of system-written preferences. AppleAquaColorVariant also does not represent Increase Contrast. Replace these probes with the corresponding NSWorkspace accessibility properties. [UserDefaults reason definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons?language=objc).

Acceptance: inspect the final archive's manifest; open its policy link; verify Increase Contrast and Reduce Transparency through the supported APIs. No claim of an actual Apple rejection is made.

### 2. P2 — Repair folder-command routing and scope shortcuts to visible content

**Runtime reproduced:** from a loaded viewer, one Cmd+O returns to welcome without presenting a picker. The second invocation opens it. On that welcome screen, Delete prompts to trash the previously viewed `brick-alley` image; the prompt was canceled and no image was deleted.

[ContentView.swift:38](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/ContentView.swift:38>) handles Open Folder by replacing the viewer, while the picker subscriber lives inside the newly mounted [FolderSelectionView.swift:14](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/FolderSelectionView.swift:14>). [ContentView.swift:44](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/ContentView.swift:44>) retains the key monitor on welcome. Its [focus guard](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/KeyCaptureViewRepresentable.swift:56>) exempts text editing but not focused buttons/sliders. Plain B sets an unobserved navigation flag at [ImageViewerViewModel.swift:730](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift:730>).

Use one persistent folder presenter; preserve the current session on cancellation; route Back to the visible navigation state; activate viewer shortcuts only for the visible viewer and appropriate focus.

Acceptance: first Cmd+O opens the picker; Cancel retains the photo; B returns to welcome; Delete/S/Return on welcome do not operate on a hidden image; keyboard activation of buttons and sliders still works.

### 3. P2 — Reconcile Trash completion by the captured file identity

Source-confirmed, not exercised destructively. [ImageViewerViewModel.swift:971](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift:971>) receives the asynchronous recycle completion for a captured URL, then [line 1015](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift:1015>) removes the then-current index. Navigation, sorting, or switching folders while recycling can remove a different item from the visible list. Scoped access also ends before the callback completes.

Capture the folder and URL, retain scope until completion, and reconcile that identity only if the affected folder is still displayed. Add a controllable recycler regression covering late completion after navigation/sort/folder changes. The evidence shows incorrect list reconciliation; it does not show a different physical file being recycled.

### 4. P2 — Make advertised formats, preferences, and release copy truthful

| Current behavior / evidence | Required correction |
| --- | --- |
| [README.md:45](/Users/vinnycarpenter/Projects/SimpleImageViewer/README.md:45), [HelpContent.swift:547](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Models/HelpContent.swift:547>), and submission copy promise animated GIF, SVG, and PDF. The production decoder renders GIF frame zero; a valid SVG passes type filtering but fails ImageIO decoding as corrupted; PDF is filtered out. Generated fixtures reproduced these paths. | Correct format promises and filtering to match the shipping implementation, or implement the missing rendering paths with format regressions before retaining the claims. |
| [README.md:81](/Users/vinnycarpenter/Projects/SimpleImageViewer/README.md:81) says macOS 12+, as do development sections, while the actual minimum is macOS 26.0. | Make all system requirements consistent with the intentional 26.0 floor; use that clarification to resolve the existing download complaint. |
| [PreferencesTabView.swift:475](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/PreferencesTabView.swift:475>) exposes thumbnail sizing/badges and toolbar style settings that the active Studio views do not consume. Custom shortcut persistence is disconnected from hardcoded KeyboardHandler dispatch. Confirm-delete and loop-slideshow preferences also lack runtime consumers. Controls were visible in the running Preferences window; lack of effect was traced in source. | Hide unsupported controls for this release or wire each to the actual consumer with a behavioral check. The working toolbar density slider is distinct from these unused default-thumbnail preferences. |
| [HelpContent.swift:393](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Models/HelpContent.swift:393>) says disabling Insights hides it; line 403 says OCR is not used. Both contradict current behavior. | Describe Vision observations/OCR, exact recognized-text excerpts, the persistent disabled tab, and current platform requirements. |
| [AppStoreSubmission.md:14](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Documentation/AppStoreSubmission.md:14>) and [AppStoreReviewNotes.md:3](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Documentation/AppStoreReviewNotes.md:3>) still describe 4.0.0/build 29. Copy also describes read-only access despite read-write entitlements and Move to Trash. | Refresh the copy for 4.5.1 (35), explain file permission use accurately, and check the actual listing before submission. Bundled What's New already matches 4.5.1. |

### 5. P2 — Prevent compact Grid toolbar collisions and supply accessible labels

**Runtime reproduced at the app's 800-point minimum width:** the centered mode control overlaps slideshow/share controls in Grid mode. The independent ZStack layout at [StudioToolbar.swift:29](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/StudioToolbar.swift:29>) reserves no horizontal space between its center and right groups. Removing segment text below 1020 points is insufficient.

Use a layout that reserves space for all groups and collapses secondary controls into overflow as needed. At the same width, the accessibility tree calls the modes `Photo`, `rectangle.grid.1x2`, and `square.grid.3x3`; [StudioToolbar.swift:139](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/StudioToolbar.swift:139>) needs explicit labels based on `mode.displayName`.

Acceptance: inspect Single/Strip/Grid at 800, 1020, and default width, with a long folder name and inspector open; controls must remain separate, clickable, and named Single/Strip/Grid to assistive technology.

## Additional open reliability and polish work

These were rechecked against current source; they are not inferred from the prior review's status.

| Priority | Evidence and trigger | Repair / acceptance |
| --- | --- | --- |
| P2 | **Session restoration never starts a scan.** [ContentView.swift:324](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/ContentView.swift:324>) assigns selectedFolderURL and waits 0.5 seconds, but assignment has no scan binding. | Resolve bookmark, await scan, then restore saved selection. Test cold launch, slow/unavailable storage, and a missing saved image. |
| P2 | **Recent-folder bookmark associations can be reordered.** When regenerating a stale bookmark, [SecurityScopedBookmarkManager.swift:253](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Services/SecurityScopedBookmarkManager.swift:253>) saves unordered dictionary values, while [FolderSelectionViewModel.swift:213](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/FolderSelectionViewModel.swift:213>) matches URLs and bookmarks by array index. | Store a URL/bookmark record together and migrate existing records. Verify several recent folders and stale-bookmark renewal across relaunch. Not reproduced against the user's bookmarks. |
| P2 | **External folder changes leave stale lists/thumbnails.** [FileSystemService.swift:158](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Services/FileSystemService.swift:158>) has no production monitoring caller. [FilmstripView.swift:102](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/FilmstripView.swift:102>) and GridPane thumbnail tasks are keyed only by URL. Stage revision refresh does not solve list/thumbnail refresh. | Own one active-folder monitor and reconcile file identities and thumbnail revisions. Verify external add/delete/replace and selection retention. |
| P2 | **Breadcrumb folder-switch failures have no UI feedback.** [StudioToolbar.swift:53](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/StudioToolbar.swift:53>) observes only successful content, while [FolderSelectionViewModel.swift:367](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/FolderSelectionViewModel.swift:367>) places scan errors only in its own currentError. | Bind that picker's progress, cancellation, and errors to visible UI; retain the prior photo after failure. Empty/unreadable-folder behavior is source-confirmed, not a completed runtime reproduction in this pass. |
| P2 | **Metadata copy lacks an explicit accessible control.** [InspectorView.swift:340](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/InspectorView.swift:340>) uses a tap gesture and color-only feedback. The runtime AX tree exposes rows as unknown elements with a copy hint. | Provide a semantic Copy action and textual/checkmark success feedback. Verify keyboard and VoiceOver activation. |
| P3 | **Sort label can survive a new folder without its comparator.** [ImageViewerViewModel.swift:198](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift:198>) installs the scanner's name-sorted list without resetting/reapplying sortOrder. | Apply the selected sort on folder load or reset its label. Test Size → open another folder. |
| P3 | **Welcome's context-menu Preferences is a placeholder.** [FolderSelectionView.swift:144](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/FolderSelectionView.swift:144>) says preferences will arrive in a future update. | Route it to the existing preferences coordinator. |
| P3 | **Keyboard Shortcuts help opens the generic Help entry.** [SimpleImageViewerApp.swift:143](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/SimpleImageViewerApp.swift:143>). | Pass the keyboard section as the initial selection. |
| P3 | **Some welcome-screen scale transitions ignore Reduce Motion.** [FolderSelectionView.swift:258](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/FolderSelectionView.swift:258>) and the recent-folder hover transition at line 488. | Gate spatial transitions with the system Reduce Motion setting, as the active inspector/filmstrip/grid already do. |

## GitHub and submission gates

- **Exact release commit has no CI proof.** A live GitHub check-runs query for `448cd7e549c22c3c7b85f16c4519381498f503cc` returned zero checks; the commit-specific workflow query also returned no runs. The passing older [Build and Test](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/33704961339) and [CI](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/33704961295) runs cover `74e7b83`, not this release commit. Confirm CI on the final integrated release SHA.
- **Two PRs remain open:** [#18, BeforeAfterSliderView](https://github.com/vscarpenter/SimpleImageViewer/pull/18) and [#19, ThinkingIndicatorView](https://github.com/vscarpenter/SimpleImageViewer/pull/19). Their historical build checks passed; each has a failed claude-review check and GitHub reports UNSTABLE. These do not prove current release readiness. Decide their inclusion and resolve their review state without assuming they are already in main.
- **PR #18 has component-level review debt:** its inline comments still match current [BeforeAfterSliderView.swift:59](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Views/BeforeAfterSliderView.swift:59>): before/after labels identify the opposite visible halves, releasing outside the automatic sweep range causes a jump, and the divider lacks an adjustable accessibility action. Its five tests also retain naming inconsistent with repository guidance. These are valid cleanup items, but the unused component has no active viewer entry point, so they are not user-facing deployment blockers. The review bot's P1 label on test naming overstates release impact.
- **Two GitHub issues remain open:** [#10, Cannot download from App Store](https://github.com/vscarpenter/SimpleImageViewer/issues/10), concerns the macOS 26 requirement versus macOS 12 documentation; the mismatch still exists in README. [#5, Testing form](https://github.com/vscarpenter/SimpleImageViewer/issues/5), appears to be feedback-form housekeeping, not evidence of a runtime release blocker.
- **App Store Connect could not be inspected:** direct navigation redirected to login with `authResult=FAILED`. Selected build, build-number availability, listing text, screenshot currency, policy/support URLs, privacy answers, age rating, and review notes remain unverified. No fields were edited.
- **Distribution archive remains a gate:** produce and validate the final signed archive, confirm its version/build, universal slices, entitlements and manifest, then verify upload processing and the selected build in App Store Connect. No distribution archive, Organizer validation, upload, or submission was performed in this review.

## Craft report and coverage limits

**Checked:** native layout, toolbar density, visual hierarchy, mode distinctions, image/metadata/Insights presentation, command behavior, preferences/help consistency, AX labels/actions, source-level motion guards, folder/file lifecycle, release configuration, manifest, test membership, local checks, and live GitHub open items.

**Passed:** Single and Strip are visibly distinct; wide Grid is coherent; the local Alley insight matches its displayed photo and remains available; the current app-hosted suites cover the recent selection, orientation, viewport, corrupt-image, cache, metadata, and Insights regressions. The reviewed on-device AI path has no remote model call, and the built app declares no network entitlement.

**Changed:** review report only. No application fixes were applied. The Trash prompt was canceled. Runtime testing added the repository sample-photo folder to Recents; no original recent-folder entry or image was intentionally removed.

**Left alone:** Compare mode was explicitly declined in `tasks/todo.md`; the reusable component's lack of a viewer toggle is intentional. A redesign, new AI features, and the speculative feature plan in `plan.md` are not required release work. Six existing lint warnings are cleanup, not a failed lint gate.

**Not established:** dark/high-contrast runtime appearance, complete VoiceOver navigation, physical trackpad gestures, long-session memory behavior, removable-drive recovery, destructive Trash behavior, a representative AI accuracy benchmark, distribution signing, exact-release CI, or live App Store submission state. Source evidence and the passing automated suite do not substitute for those checks.

**Next step:** repair the pre-submission findings above, rerun the relevant regressions and focused UI checks, then validate the exact signed release and App Store Connect record.

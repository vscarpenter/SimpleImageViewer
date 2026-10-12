# StillView 5.1.0 final polish and App Store review

Reviewed October 12, 2026 against `3fb4803d6a448ce18160eb4933c68b8bfcde5e09`, including the user's uncommitted DEBUG screenshot helper. Version remains **5.1.0 (45)**. This pass reviewed the external refinements since PR #21, browsing/session/bookmark behavior, AI/OCR lifecycle, native control semantics, release notes, privacy disclosures, CI and archive packaging.

**Verdict: I recommend addressing the four source findings below before submission.** Local tests, build and packaging pass, but this is not a distribution-signed submission approval. Current native testing stopped at control/screenshot failures, so source-traced behavior is distinguished from runtime reproduction.

**Approved follow-up:** the source findings were implemented and verified in the [release-readiness fixes report](2026-10-12-release-readiness-fixes-verification.md), including 335 passing tests and observed native menu, What’s New, recursive-filter and OCR checks. This review remains a historical snapshot of the original findings; the follow-up records its remaining native and submission limits separately.

## Findings to address before release

### P1 — Upgrade can discard an offline folder's durable grant

[PreferencesService.swift:152](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Services/PreferencesService.swift:152>) migrates legacy records and immediately saves them. Legacy resolution at line 175 skips every bookmark that throws; the setter at line 161 then deletes the original bookmark array. A transient provider/network failure during upgrade therefore turns that folder into a permanently bookmark-less record before the new startup preservation logic runs. Reconnecting cannot recover the discarded grant without choosing the folder again.

Preserve unresolved legacy bookmark data for later reconciliation instead of deleting it as soon as the first migration attempt runs. Keep successful URL/grant associations intact; never attach an unresolved grant by array position.

Evidence: current source call chain, including legacy-array deletion. A real offline-provider upgrade was not performed. A regression should force resolution failure during migration, retry successfully, and confirm the original grant is recoverable without borrowing another folder's access.

### P1 — Automatic session restoration can still mount a volume on the main actor

[WindowState.swift:315](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/Models/WindowState.swift:315>) and line 338 use `.withSecurityScope, .withoutUI` without `.withoutMounting`. Both are called by the MainActor restoration chain in [AppDelegate.swift:232](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/AppDelegate.swift:232>) through session validation/restoration. The new no-mount option in the recent-folder startup manager does not cover this separate path. An offline saved SMB/external root can therefore incur mounting work before the asynchronous scanner starts.

Make automatic session bookmark resolution non-mounting in both helpers and keep filesystem/provider validation off the main actor. Explicit user opening can retain its separate recovery behavior.

Evidence: source call chain and the installed SDK's definition of the no-mount option. No disconnected SMB/external-volume launch was reproduced. The absence of a local hang is not proof that unavailable-provider restoration is safe.

### P2 — Folder Selection leaves hidden-image menu actions active

[ContentView.swift:25](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/ContentView.swift:25>) supplies the viewer model and refresh action for the entire scene. Returning to Folder Selection at line 385 cancels work and hides the viewer but preserves the populated model. [SimpleImageViewerApp.swift:348](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/App/SimpleImageViewerApp.swift:348>) enables Image actions from that retained model, so Copy/Share/Trash can refer to an image that is no longer visible. Refresh can republish the retained folder and reopen it.

Provide viewer-only focused commands while the viewer is shown, withdrawing image/refresh commands on Folder Selection. Preserve intentional saved-session state separately.

Evidence: source-backed menu enablement and refresh publication. Native reproduction was attempted but blocked by accessibility control errors. Verify by opening a folder, returning with File → Back to Folder Selection, and checking that image/refresh actions are disabled. Do not execute Trash to prove enablement.

### P2 — Same-file reload can briefly show stale insights during metadata preparation

[ImageViewerViewModel.swift:820](</Users/vinnycarpenter/Projects/SimpleImageViewer/StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift:820>) detects a changed revision and calls `loadCurrentImage()`. Same-URL preparation at line 790 retains the old insight input/result until the new metadata worker returns. On a slow provider, pixels can finish reloading first, leaving a copyable old description/OCR result alongside the updated image.

Invalidate prior insights immediately when a changed revision is detected, before starting the reload and replacement metadata read. Add a delayed production-style metadata regression; current injected providers run synchronously and do not cover this interval.

Evidence: source completion ordering and renderer state, not an observed slow-provider run. A related preparation gap has no visible progress/Cancel until metadata completes; include that state in the same lifecycle verification.

## Completed verification

| Check | Result and scope |
| --- | --- |
| Release app-hosted tests | **307 passed, 0 failed, 0 skipped**; independently summarized from xcresult |
| Debug build | Passed, including the preserved user screenshot helper |
| Release archive | Passed with `CODE_SIGNING_ALLOWED=NO` |
| SwiftLint | Zero errors; one existing complexity warning at PreferencesViewModel.swift:671 |
| Toolchain | macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), SDK 27, arm64 |
| Test membership | 15 active test sources verified |
| Archive identity | 5.1.0 (45), com.vinny.StillView-Image-Viewer, minimum macOS 27.0 |
| Bundled resources | Current What’s New JSON, PrivacyInfo.xcprivacy and AppIcon.icns verified |
| Release exclusion | No DEBUG snapshot helper/menu or CGWindowListCreateImage string in the archived executable |
| Local runtime copy | Ad hoc signed with the unchanged three sandbox/folder entitlements; strict signature verification passed |
| Hosted CI at reviewed HEAD | CI and Build and Test succeeded; the latter passed 307 tests and unsigned archive/export |
| CodeQL | Explicitly paused for the known Xcode 27 toolchain incompatibility; no current scan result claimed |
| Metadata limits | Subtitle 29/30 characters; promo 160/170; description 2590/4000; keywords 97/100 UTF-8 bytes; What’s New 1417/4000 characters; reviewer notes 3939/4000 UTF-8 bytes |

The suite ran before release-copy edits. The final archive afterward contains the updated JSON byte for byte. Only documentation changed after that archive; functional source was not modified by this review. All current Store copy fields fit [Apple's field definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information). An early review count of 172 characters for the original promotion was incorrect: independent extraction found **162**, already within the limit. The rewrite fixes attribution, not a length violation.

Local evidence: [validation](</Users/vinnycarpenter/Projects/SimpleImageViewer/docs/reviews/evidence/2026-10-12/final-polish-validation.json>), [test summary](</Users/vinnycarpenter/Projects/SimpleImageViewer/docs/reviews/evidence/2026-10-12/final-polish-test-summary.json>), and [native signature inspection](</Users/vinnycarpenter/Projects/SimpleImageViewer/docs/reviews/evidence/2026-10-12/final-polish-native-signature.txt>).

The archive is `/tmp/stillview-final-polish-2026-10-12.xcarchive`. Its unsigned executable SHA-256 is `cc6734aa94c2aece8802399d9d289f6a599e1b41ee0c067378d2ea3926f9caae`. The native verification copy is `/tmp/stillview-final-polish-native-2026-10-12/StillView - Simple Image Viewer.app`.

[Hosted CI](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/38258267674) and [Build and Test](https://github.com/vscarpenter/SimpleImageViewer/actions/runs/38258267715) cover committed HEAD, not these uncommitted release-copy updates.

## Native and visual verification boundary

The rebuilt, sandboxed archive copy launched. Accessibility showed the restored collection, toolbar, source list and Info/Insights controls. Help opened and exposed What’s New. Subsequent menu clicks and cancellation returned stale-element errors; screenshots were unavailable. Rebinding and resetting computer controls did not recover interaction. User assistance was requested.

Consequently this pass does **not** claim a completed current What’s New dialog, folder-selection menu reproduction, grid/tree keyboard walkthrough, visual appearance/contrast check, VoiceOver run, screenshot capture or signed relaunch/OCR check. The prior October 11 walkthrough remains historical evidence and was not substituted for these current refinements. A process running and an accessibility tree are not full visual proof.

## Release-copy polish completed

| Before | After | Why |
| --- | --- | --- |
| In-app notes omitted later refinements and made absolute restore/recognition claims | Six concise items include the refinements and qualify available files, partial OCR and model readiness | Accurate, readable What’s New for the submission candidate |
| Store copy attributed recognized text to Apple Intelligence and promised generated detail sections | Apple Intelligence descriptions and Vision text are distinguished; notes match title/summary output | Reviewers and customers see behavior actually implemented |
| Submission package recommended old 5.0 captures | It now requires current 5.1 captures and identifies the kit as a plan | [Apple requires screenshots to represent the app](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) |
| Notes/keywords limits were called character limits; old ASC verification sounded current | UTF-8 byte limits and historical verification are explicit | Correct validation and honest release provenance |
| Architecture described tags/detail/800-token responses and OCR prompt budgeting | It now describes current narrow schemas, 350-token responses and independent Vision text | Keep implementation documentation consistent with production |

Updated files: whats-new.json, CHANGELOG.md, AppStoreSubmission.md, AppStoreReviewNotes.md and AI_Insights_Architecture.md. Version/build and the provisional October 11 release date were preserved. Confirm the intended release date before the actual submission archive; if changed, rebuild.

## Remaining submission work

- Fix and verify the source findings above, then complete the current native walkthrough.
- Capture fresh 5.1 screenshots; `marketing/screenshots-5.1.0/` currently contains the shot plan/scripts/demo assets, not a completed listing set.
- Update the public [privacy policy's AI section](https://stillviewapp.com/privacy.html#ai-insights): it still refers to optional details/tags and treats all analysis as model-dependent. Describe concise Foundation Models output and independent Vision extraction separately. No additional collection/network behavior was found; this is disclosure consistency. The public website was not changed.
- Validate the actual distribution-signed archive in Xcode Organizer, including provisioning/signature, expected sandbox entitlements and absent get-task-allow. The ad hoc copy and unsigned CI archive are separate proof.
- Inspect App Store Connect for build-number uniqueness, selected build, privacy answers, age rating, export compliance, metadata, contact information and screenshots. No current account state or upload/approval was verified. This checklist does not require Developer ID notarization for the Mac App Store path.
- Recheck public privacy/support URLs and accessibility claims for the release actually submitted.

## Craft report

**Checked:** image-first composition and existing native design constraints; commands/focus state; folder/scan/sandbox lifecycle; AI/OCR preparation and revision state; copy feedback; release-copy hierarchy; metadata limits; packaging, DEBUG exclusion and privacy declarations. Native visual coverage is limited as described above.

**Passed:** current source preserves cancellable discovery generations, original-folder worker grants, Trash invalidation, deterministic filtering, concise on-device descriptions, independent exact-as-recognized OCR, partial-text notices and Insights copy announcements. Build/test/archive and current hosted checks substantiate compilation and regression coverage.

**Changed:** five release/documentation files above, with the explicit before/after/rationale table. No functional implementation, Xcode project, public website or user's screenshot helper was changed.

**Left alone:** existing palette, SF typography, native controls, image-first layout and restrained motion; the single combined collection/tree signature remains. Existing lint warning is not a new release defect. Minor Info copy feedback/heading semantics and broadly worded Help privacy text merit later polish. Rapid same-root scope/refresh/sidebar interactions and real disconnected providers remain runtime bounds, not invented findings. No new AI accuracy claim was inferred from older completion/delivery measurements.

**Verdict:** the candidate builds and its release notes are current; complete the source corrections, native verification and distribution/Store checks before calling it submission-ready. No commits, pushes, uploads or publications were performed.


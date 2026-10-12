# Approved 5.1 release-readiness fixes

The user approved fixing the bookmark, Folder Selection menu and stale-insights findings from the October 12 review, then verifying, committing, pushing and opening a PR with the updated What’s New. Deliver on `codex/5-1-release-readiness-fixes`; retain version 5.1.0 (45).

## Behavior to deliver

1. Preserve unresolved legacy folder grants for later safe reconciliation. Never borrow a grant by array position. Explicit removal and clearing must prevent removed folders from returning on retry.
2. Automatic session restoration must not mount unavailable volumes or do blocking provider validation on the main actor. A user opening another folder or returning to Folder Selection cancels delayed restoration. Preserve the existing synchronous quit and early-autosave protections.
3. Expose image/refresh/scope menu commands only while the viewer is visible. Keep Open Folder and Back commands available, and preserve saved collection state while the welcome screen is visible.
4. Invalidate old description/OCR state as soon as a changed file revision is detected. Metadata preparation must have visible progress/cancellation and reject stale completion, while unchanged-file refresh retains its accepted results.
5. Include the release-copy updates from the review and add concise What’s New coverage for these corrections. Preserve historical release notes and describe remaining submission prerequisites accurately.

## Verification and delivery

Add regressions in existing active test sources before fixes, record RED and GREEN results, and serialize Xcode builds/tests. Run the full app-hosted suite, Debug/Release checks appropriate to the changes, lint and test membership validation. Inspect a rebuilt sandboxed app when native controls are available; do not replace a missing runtime check with a source claim. Obtain independent final integration review and verify the pushed SHA/PR checks separately from local results.

The user's pre-existing DEBUG screenshot helper in `SimpleImageViewerApp.swift` must remain intact and uncommitted. Do not hand-edit the Xcode project, change entitlements, publish the website, upload an App Store build or merge the new PR.

## Completed local verification

Behavior and release-copy changes are committed in `a79e1cf`. All 335 app-hosted Release tests pass; Debug build, unsigned Release archive, lint and test membership checks pass. Independent final source review is clear. Native observations include disabled Folder Selection commands, updated What’s New, recursive branch/search filtering, 47-line OCR with Insights off and sandboxed autosave restoration after restarting the verification copy. See the [verification report](../reviews/2026-10-12-release-readiness-fixes-verification.md) for evidence, preservation checks and remaining native/Store submission bounds. Push and PR delivery are authorized downstream steps; their live status is reported separately.

## PR 27 review follow-up

The user authorized checking the completed Codex reviews and fixing verified findings. One P2 exposed welcome/context/recent choices that bypassed restoration cancellation. `da2f495` centralizes explicit intent in the picker, with the scene's exact restoration manager injected during StateObject initialization; automatic restore/Refresh/scope operations stay separate. Five additional regressions bring the full passing suite to 340. Debug build, unsigned Release archive, lint, membership and independent source review pass. See the [follow-up verification](../reviews/2026-10-12-pr27-codex-review-followup.md).

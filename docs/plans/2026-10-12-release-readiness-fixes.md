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

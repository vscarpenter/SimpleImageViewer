# StillView 5.0.0 (40) launch readiness review

Reviewed September 15, 2026, on `main` at `9470f6b` (Xcode 27.0, macOS 27.0 26A428). Fixes landed as `3088a0e`, `127a0c6`, `c6f09d0`, and the docs commit that carries this file.

**Verdict: the repository is ready to archive.** Every in-repo gate passes. Three items outside the repository still block submission: the live privacy and terms copy for AI Insights, current screenshots, and validation of the distribution-signed archive.

## Verified

| Gate | Result |
| --- | --- |
| Release build | Succeeded, arm64 only, zero compiler warnings. |
| Unit tests | 229 passed, 0 failed, app-hosted. Membership check verified 15 active test sources. |
| SwiftLint | One pre-existing complexity warning in `PreferencesViewModel`, zero errors. Down from five warnings. |
| Info.plist | 5.0.0 (40), minimum system 27.0, photography category, non-exempt encryption false, copyright 2026. |
| Entitlements | App Sandbox, user-selected read-write, app-scope bookmarks. No `get-task-allow`. |
| Privacy manifest | No tracking, no collected data. File timestamp (C617.1, 3B52.1, DDA9.1), UserDefaults (CA92.1), system boot time (35F9.1). |
| Bundle | `PrivacyInfo.xcprivacy`, `AppIcon.icns` (all ten sizes), `whats-new.json` for 5.0.0, no debug menu. |
| Debug-only code | The Debug menu and `InsightEvalHarness` compile only under `DEBUG`. Release builds contain no `print` calls. |
| Network | No `URLSession` use. Outbound links open in the browser. No update checker or analytics. |
| CI | Build and Test, CI, CodeQL, and Release Drafter all green on `9470f6b`. No open PRs or issues. |
| Help and Settings copy | Formats, macOS 27 requirement, Trash behavior, and the Insights description match the shipped behavior. |

## Fixed in this pass

- Copyright year moved to 2026 in the Info.plist key. About now reads the notice from the bundle, and a smoke test fails when the year goes stale.
- The privacy manifest declares the system boot time category for the elapsed-time measurement in `AppleIntelligenceInsightsService`.
- Menu items, placeholders, and progress text use the ellipsis character. Welcome and context menus say Settings. Hover-effects help says System Settings.
- The disabled "Remove from View" placeholder left the thumbnail context menus, with its dead service action.
- Inspector metadata rows expose a button trait and a VoiceOver Copy action.
- The welcome screen honors Reduce Motion for its two scale animations.
- `AppStoreSubmission.md` and `AppStoreReviewNotes.md` describe 5.0.0 (40). `KeyboardNavigation.md` says Settings. README states the macOS 27 requirement without hedging. CHANGELOG names the release.

## Remaining gates outside the repository

1. **Live policy copy is wrong for 5.0.** On September 15 both `https://stillviewapp.com/privacy.html` and `https://stillviewapp.com/terms.html` returned 200. The folder, sharing, and GitHub-draft corrections from September 6 are live. The AI Insights section on both pages still says Vision identifies categories and counts faces, that the language model "never receives image pixels," and that the feature needs macOS 26. In 5.0 the image goes to the on-device Foundation Models model, and the app requires macOS 27. Replacement wording is below. Publish it, then confirm the privacy URL in App Store Connect.
2. **Screenshots.** The checked-in set in `marketing/screenshots-4.3.0/` predates native Settings and the Insights actions. Recapture Single, Strip, Grid, Info, Insights, and Settings at 1440 by 900 or another accepted size.
3. **Signed archive.** Archive in Xcode, validate in Organizer, then confirm with `codesign -d --entitlements - "<App>.app"` that the distribution app carries sandbox, read-write, and bookmark entitlements and nothing else. Run the release smoke checks, including a disposable-image Trash and recovery check.
4. **App Store Connect.** Confirm the selected build, privacy answers, age rating, and the metadata in `AppStoreSubmission.md`. Set `releaseDate` in `Resources/whats-new.json` to the submission date; the in-app sheet shows it.
5. **GitHub Releases.** The latest published release is v2.4.0 and Release Drafter's draft is titled v2.4.1. When publishing, set the tag and title to v5.0.0 by hand.

### Replacement copy for the AI Insights sections

Use this on both pages in place of the current opening paragraph.

> AI Insights sends the selected image to Apple's on-device Foundation Models framework on your Mac. Apple Intelligence describes the visible content, may note one useful detail, and may suggest tags. Apple's Vision framework recognizes text in the image, and StillView shows that text as recognized, without rewriting it. Descriptions can be incomplete or wrong, and they do not identify people. The feature requires a Mac with Apple silicon running macOS 27, with Apple Intelligence turned on and its on-device model ready.

Keep the existing second paragraph. It is still accurate: everything stays on the Mac, nothing is uploaded, and there is no cloud fallback.

## Known backlog, not blocking

- Recent-folder bookmark regeneration saves unordered dictionary values (`SecurityScopedBookmarkManager.swift:254`) while the view model matches by index.
- `FileSystemService.monitorFolder` has no production caller. The viewer refreshes when a folder is reselected.
- The sort label can survive a folder change without its comparator being reapplied.
- One SwiftLint complexity warning remains in `PreferencesViewModel`.
- 56 test files on disk are not in the test target. The test bundle identifier is still `com.example.StillViewTests`.
- Stale root documents: `BUILD_STATUS.md` (refers to the removed AIAnalysis module), `IMPLEMENTATION_SUMMARY.md` (describes the removed Favorites feature), `stillview-prd.md` (macOS 12, version 2.5), `plan.md`, `GEMINI.md`, and `add_files_to_project.py`.
- Twelve local branches are merged into `main`, and `.claude/worktrees/elated-driscoll` is a stale detached worktree. Deleting either needs the owner's confirmation.
- The `AccentColor.colorset` folder is empty and untracked. The build setting still names it, the build does not warn, and the app follows the system accent as intended.
- Optional: an Icon Composer `.icon` file would give the app a designed Liquid Glass icon. The legacy icon set renders correctly on macOS 27.

## Not established by this pass

Distribution signing, Organizer validation, a VoiceOver walkthrough, dark and high-contrast appearance checks, long-session memory behavior, and external-volume recovery. Source evidence and the automated suite do not replace those checks.

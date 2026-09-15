# macOS 27 App Store launch polish (5.0.0 build 40), 2026-09-15

Tier: Standard. Branch: main (solo repo; CI green on 9470f6b). Review-first, then bounded fixes.

## Verified green before changes
- Release build (Xcode 27.0, SDK 27.0): succeeded, arm64 only, zero compiler warnings.
- Debug test suite: 228 tests, 0 failures. Test-target membership check passed.
- SwiftLint: 5 pre-existing warnings, 0 errors.
- Info.plist: 5.0.0 (40), LSMinimumSystemVersion 27.0, photography category, non-exempt encryption NO.
- Entitlements: sandbox, user-selected read-write, app-scope bookmarks; no get-task-allow.
- Privacy manifest, AppIcon.icns, whats-new.json all present in the built bundle.
- GitHub: no open PRs or issues; all checks green on HEAD.

## Fixes (this pass)
- [x] Copyright year 2025 -> 2026 in Info.plist key; About reads it from the bundle (test first in SmokeTests)
- [x] Privacy manifest: declare SystemBootTime (35F9.1) for ProcessInfo.systemUptime in AppleIntelligenceInsightsService
- [x] Menu and UI strings: true ellipsis, "Settings…" instead of "Preferences…", "System Settings"
- [x] Remove the permanently disabled "Remove from View" placeholder context menu item and its dead service action
- [x] Inspector metadata rows: add an accessibility Copy action and button trait
- [x] Welcome screen: honor Reduce Motion for the two scale animations
- [x] Lint: four aspectRatio(contentMode:) calls -> scaledToFit/scaledToFill
- [x] Docs: AppStoreSubmission.md and AppStoreReviewNotes.md to 5.0.0 (40); KeyboardNavigation.md Settings wording; README requirement hedge; CHANGELOG heading
- [x] Record review: docs/reviews/2026-09-15-macos27-launch-readiness.md with remaining external gates (live privacy copy, screenshots, signed archive)
- [x] Rebuild Release, rerun tests and lint; commit per logical unit

## Assumptions
- Copyright year is the current year (2026); the earlier 2025 line stays only in source-file header comments.
- Release date in whats-new.json (2026-09-06) is left for the owner to set at submission time.
- Deleting merged local branches and the stale .claude worktree needs owner confirmation; listed, not done.

## Verified green after changes
- Release build: succeeded, arm64, zero compiler warnings; bundle shows 5.0.0 (40), copyright 2026, manifest with 35F9.1.
- Tests: 229 passed, 0 failed (new copyright-year smoke test included).
- SwiftLint: 1 pre-existing complexity warning, 0 errors.

## Resuming From Here
- Done: all fix items above, committed as 3088a0e, 127a0c6, c6f09d0, plus the docs commit. Nothing pushed.
- Next (owner): publish the AI Insights policy copy from docs/reviews/2026-09-15-macos27-launch-readiness.md, recapture 5.0 screenshots, archive and validate in Organizer, set whats-new.json releaseDate at submission, push main.
- Blockers: none in-repo.
- Note: xcode-select points at CommandLineTools on this Mac; prefix xcodebuild and swiftlint with DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer.

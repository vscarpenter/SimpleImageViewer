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

# Legal pages and 5.0 marketing screenshots, 2026-09-15

Tier: Standard. Two repos: this one (marketing/screenshots-5.0.0) and ~/Projects/stillviewapp.com.

- [x] stillviewapp.com: rewrite AI Insights sections on privacy.html and terms.html, effective date Sept. 15, sitemap lastmod; committed 8397f05 (not pushed, not deployed)
- [x] Re-apply window snapshot rig by hand (patch no longer applied); Debug build ad-hoc signed with entitlements
- [x] Capture eight 2880x1800 frames: hero, zoom, immersive, navigation, info (dark); grid, insights, Settings/Shortcuts (light)
- [x] finalize.swift + caption_bake.swift for 2x output into marketing/screenshots-5.0.0
- [x] Swap the three landing page feature images to stillview50-* and bump sitemap index lastmod
- [x] Revert the rig from SimpleImageViewerApp.swift; restore Light appearance; quit app; remove scratch Landscapes recent entry
- [x] Commit marketing set (app repo, 27964c6) and landing swap (site repo, 98b5941); deploy.sh and push wait for Vinny's go-ahead

Assumptions: Suggested tags stayed collapsed in the Insights frame (automation could not toggle the disclosure). Website keeps only the three feature images it already uses.

## Resuming From Here (2026-09-15, afternoon)
- Done: legal copy (site 8397f05), landing swap (site 98b5941), marketing/screenshots-5.0.0 (27964c6), docs pointers (69cb99f). Working trees clean in both repos. App quit, appearance back to Light, scratch recent entry removed.
- Done later the same day: both repos pushed to origin; site deployed (invalidation IC8CKD58V2LTM08A295P2XLQDW completed) and verified live.
- Next (Vinny): archive and validate in Organizer; upload; set whats-new.json releaseDate at submission; confirm the privacy URL and screenshots in App Store Connect.
- Blockers: none in-repo.

# Build 44 sync after the Xcode archive, 2026-09-15

Tier: Trivial. Branch: main.

- [x] Commit the build number change (40 to 44) that Xcode wrote before the 10:55 AM archive
- [x] CHANGELOG, AppStoreSubmission.md, and AppStoreReviewNotes.md name 5.0.0 (44)
- [x] README shows the command line test run with the CI signing flags; the local CLAUDE.md (gitignored) says the same
- [x] Tests: 229 passed, 0 failed

## Resuming From Here (2026-09-15, late morning)
- Done: 0b23665 syncs the project and release docs to the 5.0.0 (44) archive; the next commit fixes the test command in the docs. Nothing pushed.
- Next (Vinny): upload build 44 from Organizer, confirm 5.0.0 (44) and the privacy URL in App Store Connect, then push main.
- Decision (Vinny): whats-new.json inside build 44 still says releaseDate 2026-09-06. Changing it means build 45 and a fresh archive.
- Blockers: none in-repo.
- Note: local `xcodebuild test` needs CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO, as in ci.yml. Without them the ad-hoc test bundle fails to load into the team-signed app.

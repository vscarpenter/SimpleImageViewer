# Contributing to StillView - Simple Image Viewer

Thanks for your interest in contributing! This guide gets you productive quickly and keeps changes consistent.

## Quick Start
- Clone and open: `open "StillView - Simple Image Viewer.xcodeproj"` (build/run with ⌘R)
- Tests: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Lint: `swiftlint` (config in `.swiftlint.yml`)

## Git Hooks (recommended)
Install the pre-commit hook to run SwiftLint automatically:
- `bash scripts/install-git-hooks.sh`
- Requires SwiftLint: `brew install swiftlint`

## Coding Standards
- Follow Swift API Design Guidelines and our SwiftLint rules (4-space indent, 120-char lines, avoid `print()`, avoid force unwraps).
- Naming: `PascalCase` types, `camelCase` members; suffixes `...View`, `...ViewModel`, `...Service`.

## Commits & PRs
- Use Conventional Commits where possible: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`.
- Open PRs with a clear summary, screenshots/GIFs for UI changes, test notes, and linked issues (e.g., `Closes #123`).
- CI must be green (build, tests, lint). Lint failures block merges.

## Tests
- Prefer unit tests for ViewModels/Services and integration tests for critical flows.
- Place tests under `StillView - Simple Image Viewer Tests/` mirroring the source layout.

## Security & Privacy
- App runs offline; do not add telemetry or secrets.
- Respect sandbox entitlements; use Security-Scoped Bookmarks for folder access.

## More
- See `AGENTS.md` for repository guidelines, structure, and commands.

Happy contributing!

## Releases
- Automated drafts: Release Drafter updates a draft release on pushes to `main` and PR activity.
- Categorization by labels: `enhancement/feat` (Features), `improvement/refactor/performance` (Improvements), `bug/fix` (Bug Fixes), `docs`, `tests`, `ci/chore`, `security`, `design`.
- Versioning rules: default is patch; `breaking-change` → major, `enhancement/feat` → minor, others → patch.
- How to cut a release (maintainers):
  1. Open GitHub → Releases → Draft release.
  2. Review/edit notes; ensure merged PRs are properly labeled.
  3. Click Publish to create tag `vX.Y.Z` and finalize notes.
- Exclude from changelog: apply `skip-changelog` to omit a PR from release notes.

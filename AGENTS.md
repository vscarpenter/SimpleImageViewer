# Repository Guidelines

## Project Structure & Module Organization
- `StillView - Simple Image Viewer/`: app source
  - `App/`, `Models/`, `ViewModels/`, `Views/`, `Services/`, `Extensions/`, `Resources/`, `Documentation/`
- `StillView - Simple Image Viewer Tests/`: XCTest targets mirroring sources (e.g., `Views/`, `Services/`)
- Xcode project: `StillView - Simple Image Viewer.xcodeproj`

## Build, Test, and Development Commands
- Open in Xcode: `open "StillView - Simple Image Viewer.xcodeproj"` (build/run with ⌘R)
- Resolve packages: `xcodebuild -resolvePackageDependencies -project "StillView - Simple Image Viewer.xcodeproj"`
- Build (Debug): `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO`
- Test (XCTest): `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Lint (SwiftLint): `swiftlint --reporter github-actions-logging` (config: `.swiftlint.yml`)

## Coding Style & Naming Conventions
- Swift + SwiftUI; follow Swift API Design Guidelines.
- Indentation: 4 spaces; line length: 120 (warnings at 120 via SwiftLint).
- Naming: `PascalCase` types (`ImageViewerViewModel`), `camelCase` members, `snake_case` never.
- Suffixes: `...View`, `...ViewModel`, `...Service`, `...Coordinator`, `...Tests`.
- Avoid `print()` (SwiftLint rule); prefer `os.log` or a logging utility.
- Avoid force unwraps/implicitly unwrapped optionals (opt-in rules enabled).

## Testing Guidelines
- Framework: XCTest; tests live under `StillView - Simple Image Viewer Tests/` mirroring source folders.
- File naming: `TypeNameTests.swift`; method naming: `test_<behavior>_<condition>()`.
- Run: from Xcode Test navigator (⌘U) or `xcodebuild test` (see above).
- Aim to cover ViewModels, Services, and critical Extensions; use protocol mocks where services are abstracted.

## Commit & Pull Request Guidelines
- Commits: prefer Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`); imperative, concise subject; body for rationale.
- Link issues in PRs/commits (`Closes #123`).
- PRs: include summary, screenshots/GIFs for UI changes, test notes, and any migration steps.
- CI: GitHub Actions builds, lints, and runs tests on PRs; ensure green status before request for review.

## Security & Configuration Tips
- App Sandbox entitlements: `StillView - Simple Image Viewer/Simple_Image_Viewer.entitlements` (read-only user-selected files, bookmarks).
- No network required; do not add telemetry or hardcoded secrets.
- Use Security-Scoped Bookmarks for persistent folder access (see `SecurityScopedAccessManager`).

## Repo Labels
- Standard labels live in `.github/labels.json`. Seed/update with `bash scripts/sync-labels.sh` (requires `gh` auth) or `REPO=owner/name GITHUB_TOKEN=... bash scripts/sync-labels.sh`.
- Apply relevant labels on issues/PRs (e.g., `bug`, `feat`/`enhancement`, `improvement`, `docs`, `ci`).

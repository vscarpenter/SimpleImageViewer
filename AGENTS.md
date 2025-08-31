# Repository Guidelines

## Project Structure & Module Organization
- `StillView - Simple Image Viewer/`: SwiftUI app source (`App/`, `Models/`, `ViewModels/`, `Views/`, `Services/`, `Extensions/`, `Resources/`, `Documentation/`).
- `StillView - Simple Image Viewer Tests/`: XCTest targets mirror source folders (e.g., `Views/`, `Services/`).
- Xcode project: `StillView - Simple Image Viewer.xcodeproj`.

## Build, Test, and Development Commands
- Open in Xcode: `open "StillView - Simple Image Viewer.xcodeproj"`.
- Resolve packages: `xcodebuild -resolvePackageDependencies -project "StillView - Simple Image Viewer.xcodeproj"`.
- Build (Debug, macOS): `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO`.
- Test (XCTest): `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`.
- Lint (SwiftLint): `swiftlint --reporter github-actions-logging`.

## Coding Style & Naming Conventions
- Swift + SwiftUI; follow Swift API Design Guidelines.
- Indentation: 4 spaces; line length: 120 (warnings at 120 via SwiftLint).
- Naming: `PascalCase` types; `camelCase` members; never `snake_case`.
- Suffixes: `...View`, `...ViewModel`, `...Service`, `...Coordinator`, `...Tests` (e.g., `ImageViewerViewModel`).
- Logging: avoid `print()`; prefer `os.log` or a shared logging utility.
- Safety: avoid force unwraps/implicitly unwrapped optionals; use safe patterns.

## Testing Guidelines
- Framework: XCTest. Focus on ViewModels, Services, and critical Extensions.
- File names: `TypeNameTests.swift`; methods: `test_<behavior>_<condition>()`.
- Run: Xcode Test navigator (⌘U) or the `xcodebuild test` command above.
- Use protocol-based mocks where services are abstracted.

## Commit & Pull Request Guidelines
- Commits: Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`). Imperative, concise subject; body for rationale. Link issues (e.g., `Closes #123`).
- PRs: include summary, screenshots/GIFs for UI changes, test notes, and any migration steps. Ensure CI (build, lint, tests) is green before requesting review.

## Security & Configuration Tips
- App Sandbox entitlements: `StillView - Simple Image Viewer/Simple_Image_Viewer.entitlements` (read-only user-selected files, bookmarks).
- No network required; do not add telemetry or hardcoded secrets.
- Use Security-Scoped Bookmarks for persistent folder access (see `SecurityScopedAccessManager`).

## Repo Labels
- Standard labels live in `.github/labels.json`. Sync with `bash scripts/sync-labels.sh` (requires `gh`), or `REPO=owner/name GITHUB_TOKEN=… bash scripts/sync-labels.sh`.


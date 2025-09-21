# Repository Guidelines

## Project Structure & Module Organization
Source lives in `StillView - Simple Image Viewer/` split into `App/`, `Models/`, `ViewModels/`, `Views/`, `Services/`, `Extensions/`, `Resources/`, and `Documentation/`. Tests mirror this layout under `StillView - Simple Image Viewer Tests/`; keep new test files aligned with their production counterparts. The Xcode project file is `StillView - Simple Image Viewer.xcodeproj` and should be updated through Xcode, never edited manually.

## Build, Test, and Development Commands
- `open "StillView - Simple Image Viewer.xcodeproj"` — launch the workspace in Xcode for local development.
- `xcodebuild -resolvePackageDependencies -project "StillView - Simple Image Viewer.xcodeproj"` — refresh Swift Package Manager dependencies before first build.
- `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO` — CI-friendly debug build.
- `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` — run the XCTest suite.
- `swiftlint --reporter github-actions-logging` — enforce style checks; address warnings before merging.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines with 4-space indentation and 120-character soft limit. Types use PascalCase (`ImageGridViewModel`); properties, methods, and variables use camelCase. Avoid force unwraps and implicit optionals; prefer guard/if-let. Use `os.log` or the shared logging utility instead of `print()`. Run SwiftLint locally and keep formatting consistent with SwiftFormat defaults if applied.

## Testing Guidelines
XCTest is the standard. Place new tests in `StillView - Simple Image Viewer Tests/` following the source module path. Name files `TypeNameTests.swift` and methods `test_<behavior>_<condition>()`. Exercise view models, services, and critical extensions first; add protocol-based mocks when stubbing dependencies. Execute tests with `⌘U` in Xcode or the `xcodebuild test` command above.

## Commit & Pull Request Guidelines
Use Conventional Commits (e.g., `feat: add folder bookmark caching`) in imperative voice. Link related issues in the commit body when available. Pull requests should include a concise summary, screenshots or GIFs for UI changes, and test notes outlining what was executed. Ensure build, lint, and test checks are green before requesting review.

## Security & Configuration Tips
Respect the app sandbox defined in `StillView - Simple Image Viewer/Simple_Image_Viewer.entitlements`; the app only requires read access to user-selected files. Handle persisted folder access via `SecurityScopedAccessManager` and avoid introducing telemetry, hardcoded secrets, or network calls.

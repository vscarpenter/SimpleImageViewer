# AGENTS.md

Guidance for agent-driven changes to this repo.

- Build/Lint/Test
  - Build: `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO`
  - Test: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
  - Single test: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:<TargetTests>.<TestCase>[/<TestMethod>]`
  - Lint: `swiftlint --reporter github-actions-logging`

- Code Style
  - Imports: system first, then project; no unused imports
  - Formatting: 4-space indentation, 120-char soft limit
  - Types/Naming: PascalCase for types; camelCase for vars/functions
  - Error Handling: guard/throws; avoid force unwraps; propagate meaningful errors
  - Protocols/DI: prefer protocol-based services and DI, keep concrete implementations minimal

- Tests
  - Location: StillView - Simple Image Viewer Tests/
  - Naming: TypeNameTests.swift; test_<behavior>_<condition>()

- Repo Hygiene
  - Do not edit core Xcode project files by hand; use Xcode
  - Run lint/test before pushing; ensure CI green
  - Do not commit secrets or large binaries

- Cursor/Copilot Rules
  - See .cursor/rules/ (if present) and .github/copilot-instructions.md

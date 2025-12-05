## Quick orientation for code suggestions

This repo is a macOS SwiftUI image viewer (MVVM + Combine) with protocol-oriented services and on-device AI analysis (macOS 26+).
Keep suggestions small, concrete, and consistent with existing patterns (MVVM, protocol-driven services, @MainActor for UI updates).

### Big-picture architecture (what matters)
- Root: `StillView - Simple Image Viewer/` (App, Models, ViewModels, Views, Services, Extensions, Resources, Documentation).
- Core patterns: MVVM for UI, Protocols for services (see `Services/*.swift`), Combine publishers for async state.
- Important service boundaries: File system & bookmarks (`Services/FileSystemService.swift`, `Services/SecurityScopedAccessManager.swift`), image loading & caching (`Services/ImageLoaderService.swift`, `Models/ImageCache.swift`), AI analysis (`Services/AIImageAnalysisService.swift`, `Services/AIConsentManager.swift`).

### What to keep in mind when changing code
- Avoid editing the Xcode project file by hand; use Xcode to update `StillView - Simple Image Viewer.xcodeproj`.
- UI updates must run on the main actor. Background work should use dedicated queues/publishers.
- Follow existing protocol-oriented approach: add a protocol in `Services/` and a default implementation, then update DI points (ViewModels or AppCoordinator).

### Developer workflows & commands (use these exactly)
- Open the project in Xcode: `open "StillView - Simple Image Viewer.xcodeproj"` and build/run with ⌘R.
- Resolve SPM deps: `xcodebuild -resolvePackageDependencies -project "StillView - Simple Image Viewer.xcodeproj"`.
- CI/local debug build (no codesign):
  - Build: `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO`
  - Test: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Linting: `swiftlint --reporter github-actions-logging` (address warnings before merging).

### Project-specific conventions & examples
- Naming: Types PascalCase (e.g. `ImageViewerViewModel`), properties/methods camelCase. Files mirror type names (`ImageViewerViewModel.swift`).
- Tests: placed under `StillView - Simple Image Viewer Tests/` mirroring source layout. Name test files `TypeNameTests.swift` and test methods `test_<behavior>_<condition>()`.
- Keyboard handling: AppKit NSEvent wrapped by `KeyCaptureViewRepresentable` (see `App/WindowAccessor.swift` and `Documentation/KeyboardNavigation.md`).
- Security/sandbox: Persist folder access with security-scoped bookmarks; use `SecurityScopedAccessManager` and the entitlements at `StillView - Simple Image Viewer/Simple_Image_Viewer.entitlements`.
- AI features: On-device only. See `Services/AIImageAnalysisService.swift` and `Services/AIConsentManager.swift` for consent, model fallbacks, and privacy-first behavior.

### Integration points and external deps
- Uses Swift frameworks: SwiftUI, Combine, AppKit, Vision, CoreML, ImageIO, UniformTypeIdentifiers.
- Bundled Core ML models live in Resources and are used with Vision fallbacks; prefer on-device models and graceful fallback logic.
- No network calls for AI or telemetry; avoid adding third-party telemetry or analytics.

### PR + commit guidance for generated changes
- Use Conventional Commits (e.g., `feat:`, `fix:`). Mention linked issue IDs when available.
- PR template requires referencing `AGENTS.md` and passing lint/tests. Include screenshots/GIFs for UI changes and test notes.

### When to ask for clarification
- If a change touches entitlements, sandbox, or security-scoped bookmark handling — ask before modifying (`Simple_Image_Viewer.entitlements`, `SecurityScopedAccessManager.swift`).
- If a change introduces threading or cache semantics (ImageCache/ImageMemoryManager), request a brief design note and tests.

If anything here is unclear or missing, tell me which area you want expanded (build, tests, AI features, or security) and I'll iterate.

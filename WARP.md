# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Common Development Commands

### Project Setup & Build
```bash
# Open project in Xcode (primary development environment)
open "StillView - Simple Image Viewer.xcodeproj"

# Refresh Swift Package Manager dependencies
xcodebuild -resolvePackageDependencies -project "StillView - Simple Image Viewer.xcodeproj"

# CI-friendly debug build without code signing
xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO

# In Xcode: Build with ⌘R, test with ⌘U
```

### Code Quality
```bash
# Run SwiftLint (configuration in .swiftlint.yml)
swiftlint --reporter github-actions-logging

# Install git hooks for automated linting
bash scripts/install-git-hooks.sh
```

### Single Test Execution
```bash
# Run specific test class
xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageViewerViewModelTests" CODE_SIGNING_ALLOWED=NO

# Run specific test method
xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageViewerViewModelTests/test_navigation_incrementsIndex" CODE_SIGNING_ALLOWED=NO
```

## Architecture Overview

StillView is a SwiftUI-based macOS image viewer using **MVVM architecture with protocol-oriented design**. The app emphasizes:

- **Complete privacy** (offline-only, no telemetry)
- **App Sandbox security** with security-scoped bookmarks
- **On-device AI analysis** (macOS 26+)
- **Accessibility-first design** with VoiceOver support

### Core Architectural Patterns

**MVVM + Combine**: ViewModels manage state via `@Published` properties, Views bind reactively, Services provide protocol-based abstractions.

**Protocol-Oriented Services**: All system interactions (file system, image loading, AI analysis) go through protocols with default implementations, enabling testability and dependency injection.

**Security-First Design**: Uses `SecurityScopedAccessManager` for persistent folder access within App Sandbox constraints, never requiring admin privileges.

## Project Structure

```
StillView - Simple Image Viewer/
├── App/                    # Application lifecycle and coordination
│   ├── SimpleImageViewerApp.swift     # Main app entry point
│   ├── AppCoordinator.swift           # Navigation flow management
│   ├── AppDelegate.swift              # AppKit integration
│   ├── ContentView.swift              # Root SwiftUI view
│   └── WindowAccessor.swift           # Window state management
├── Models/                 # Core data models and business logic
│   ├── ImageFile.swift                # Image file representation
│   ├── FolderContent.swift            # Folder scanning results
│   ├── ImageCache.swift               # Memory management
│   └── AIAnalysisError.swift          # AI-specific error types
├── ViewModels/             # MVVM view models with reactive bindings
│   ├── ImageViewerViewModel.swift     # Main image viewer state
│   ├── FolderSelectionViewModel.swift # Folder selection logic
│   └── PreferencesViewModel.swift     # App preferences
├── Views/                  # SwiftUI user interface components
│   ├── ImageDisplayView.swift         # Core image rendering
│   ├── FolderSelectionView.swift      # Initial folder picker
│   ├── NavigationControlsView.swift   # Image navigation UI
│   ├── AIInsightsView.swift           # AI analysis display
│   └── HelpView.swift                 # Comprehensive help system
├── Services/               # Business logic and system integration
│   ├── FileSystemService.swift        # File operations and monitoring
│   ├── ImageLoaderService.swift       # Async image loading
│   ├── SecurityScopedAccessManager.swift # Sandbox permissions
│   ├── AIImageAnalysisService.swift   # On-device AI analysis
│   ├── AIConsentManager.swift         # Privacy consent management
│   └── AIAnalysis/                    # AI analysis components
│       ├── SmartTagGenerator.swift    # Automated image tagging
│       ├── NarrativeGenerator.swift   # Image descriptions
│       └── ClassificationFilter.swift # Content classification
├── Extensions/             # Utility extensions and helpers
│   ├── UTType+ImageSupport.swift      # Image format detection
│   ├── Bundle+Resources.swift         # Resource loading
│   └── Color+Adaptive.swift           # Theme-aware colors
└── Resources/              # Assets and bundled resources
    ├── Resnet50.mlmodel               # Core ML classification model
    └── whats-new.json                 # Release notes content
```

## Key Implementation Details

### Security & Privacy Architecture
- **App Sandbox**: Defined in `Simple_Image_Viewer.entitlements` - only read access to user-selected files
- **Security-Scoped Bookmarks**: Managed by `SecurityScopedAccessManager` for persistent folder access
- **No Network**: Complete offline operation, no telemetry or data collection
- **On-Device AI**: All AI processing via Core ML and Vision framework, never cloud-based

### Image Processing Pipeline
- **Protocol-Based Loading**: `ImageLoaderService` with memory pressure monitoring
- **Intelligent Caching**: `ImageMemoryManager` handles cache size optimization
- **Format Support**: JPEG, PNG, HEIF/HEIC, WebP, GIF, TIFF, BMP, SVG via `UTType+ImageSupport`
- **Background Preloading**: Adjacent images loaded asynchronously

### AI Analysis System (macOS 26+)
- **Hybrid Intelligence**: ResNet50 Core ML model with Vision framework fallback
- **Consent-Based**: `AIConsentManager` ensures user permission before analysis
- **Smart Tagging**: Automatic categorization via `SmartTagGenerator`
- **Narrative Generation**: Natural language descriptions through `NarrativeGenerator`

### Keyboard Navigation System
- **Global Shortcuts**: AppKit `NSEvent` handling wrapped in SwiftUI via `KeyCaptureViewRepresentable`
- **Arrow Navigation**: ←/→ for prev/next, ↑/↓ for zoom
- **Mode Switching**: F (fullscreen), T (thumbnails), G (grid), S (slideshow)
- **Accessibility**: Full VoiceOver support with detailed image descriptions

## Development Guidelines

### Code Standards
- **Swift API Design Guidelines** with 4-space indentation
- **120-character soft line limit** (150 error limit in SwiftLint)
- **PascalCase** for types, **camelCase** for properties/methods
- **Avoid force unwrapping** - use guard/if-let patterns
- **Use `os.log`** instead of `print()` statements

### Testing Strategy
- **Protocol-based mocking** for service dependencies
- **XCTest** with tests mirroring source structure in `StillView - Simple Image Viewer Tests/`
- **Test naming**: `test_<behavior>_<condition>()`
- **Integration tests** for critical flows like security-scoped access

### Service Development Pattern
```swift
// 1. Define protocol in Services/
protocol NewService {
    func performOperation() async throws -> Result
}

// 2. Provide default implementation
class DefaultNewService: NewService {
    func performOperation() async throws -> Result {
        // Implementation
    }
}

// 3. Update dependency injection (AppCoordinator or ViewModels)
```

### AI Features (macOS 26+)
- **Privacy-first**: All processing on-device using Core ML
- **Graceful degradation**: Vision framework fallback for older systems
- **User consent required**: Managed through `AIConsentManager`
- **Resource management**: Automatic model loading/unloading based on usage

### Security Considerations
- **Never modify entitlements** without understanding sandbox implications
- **Use `SecurityScopedAccessManager`** for all persistent folder access
- **No hardcoded secrets** or API keys
- **Respect memory limits** with intelligent cache management

### Commit & PR Guidelines
- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- **Reference issues**: Include "Closes #123" in commit body
- **UI changes**: Include screenshots/GIFs in PR description
- **Lint-clean**: SwiftLint checks must pass before merge

## AI Analysis Components

The on-device AI system (macOS 26+) uses a hybrid approach:

### Core Components
- **`AIImageAnalysisService`**: Main coordinator for AI operations
- **`CoreMLModelManager`**: Manages ResNet50 model lifecycle
- **`EnhancedVisionAnalyzer`**: Vision framework integration with fallbacks
- **`SmartTagGenerator`**: Generates categorized tags from image content
- **`NarrativeGenerator`**: Creates natural language descriptions
- **`AIConsentManager`**: Privacy compliance and user consent

### Analysis Pipeline
1. **Consent Check**: Verify user permission via `AIConsentManager`
2. **Model Loading**: Load ResNet50 Core ML model if available
3. **Classification**: Hybrid ResNet50 + Vision framework analysis
4. **Tag Generation**: Smart tags organized by category (objects, scene, etc.)
5. **Narrative Creation**: Natural language descriptions with confidence scoring
6. **Result Caching**: Store results in `EnhancedCaptionCache`

## Common Patterns

### Error Handling
```swift
// Use custom error types for domain-specific errors
enum ServiceError: LocalizedError {
    case operationFailed
    case insufficientPermissions
    
    var errorDescription: String? {
        // Provide user-friendly descriptions
    }
}
```

### Async Service Operations
```swift
// Services use async/await with Combine publishers
func loadResource() -> AnyPublisher<Result, Error> {
    Future { promise in
        Task {
            do {
                let result = try await performAsyncOperation()
                promise(.success(result))
            } catch {
                promise(.failure(error))
            }
        }
    }.eraseToAnyPublisher()
}
```

### Memory Management
```swift
// Use weak references in closures to prevent retain cycles
.sink { [weak self] value in
    self?.handleValue(value)
}
.store(in: &cancellables)
```

This project prioritizes user privacy, security, and accessibility while providing a clean, native macOS experience. All changes should maintain these principles while following the established architectural patterns.
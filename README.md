# StillView - Simple Image Viewer

> **"Because sometimes, simple is perfect."**

[![macOS](https://img.shields.io/badge/macOS-12.0+-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange)](https://swift.org/)
[![App Store](https://img.shields.io/badge/Available_on-Mac_App_Store-blue?logo=apple)](https://apps.apple.com/us/app/stillview-image-viewer/id6749210445)

A minimalist, elegant image viewer designed specifically for macOS users who want a clean, distraction-free way to browse through image collections. Built with SwiftUI and optimized for the Mac App Store with advanced features like thumbnail navigation, slideshow mode, and comprehensive help system.

## Table of Contents

- [Features](#-features)
- [System Requirements](#-system-requirements)
- [Installation](#-installation)
- [Architecture Overview](#-architecture-overview)
- [Core Components](#-core-components)
- [Supported Image Formats](#-supported-image-formats)
- [Security & Privacy](#-security--privacy)
- [Keyboard Navigation](#-keyboard-navigation)
- [API Documentation](#-api-documentation)
- [Development Setup](#-development-setup)
- [Testing](#-testing)
- [Contributing](#-contributing)

## ✨ Features

### 🖼️ **Effortless Browsing**
Browse through entire folders of images with intuitive keyboard shortcuts. No complex menus or overwhelming interfaces—just pure image viewing.

### ⌨️ **Keyboard-First Design**
- **Arrow keys** for navigation
- **+/-** for zoom control
- **F** or **Enter** for fullscreen
- **Space** for next image (or pause/resume slideshow)
- **Home/End** for first/last image
- **S** for slideshow mode
- **I** for image information overlay
- **T** for thumbnail strip
- **G** for grid view
- **⌘?** for comprehensive help

### 🎨 **Universal Format Support**
View all your images with crystal-clear quality:
- **Primary**: JPEG, PNG, GIF (animated), HEIF/HEIC, WebP
- **Extended**: TIFF, BMP, SVG, PDF (first page)

### 🖼️ **Advanced Viewing Modes**
- **Thumbnail Strip**: Horizontal filmstrip for quick navigation
- **Grid View**: Full-screen thumbnail grid for large collections
- **Slideshow Mode**: Automatic progression with customizable timing
- **Image Information**: Detailed metadata and EXIF data overlay
- **Pan & Zoom**: Smooth navigation of large, high-resolution images

### ✨ **macOS Native Experience**
- Full **VoiceOver** and accessibility support with detailed image descriptions
- **High contrast mode** compatibility
- **Reduced motion** preferences respected
- Native macOS design language with modern SF Symbols
- Universal Binary (Intel + Apple Silicon)
- **Comprehensive Help System** with searchable documentation

### 🧠 **Intelligent Image Analysis (macOS 26+)**
- **Powered by On-Device AI** - Industry-standard ResNet50 Core ML model for deep learning classification
- **Hybrid Intelligence** - Intelligently merges ResNet50 with Apple's Vision framework as a reliable fallback
- **Object Detection** - Identifies people, objects, and faces with confidence scoring
- **Scene Classification** - Understands image context and lighting conditions
- **Text Recognition** - OCR capabilities for extracting text from images
- **Quality Assessment** - Automated evaluation of sharpness, exposure, and technical quality
- **Smart Tags** - Automatically generated tags organized by category
- **Enhancement Suggestions** - Context-aware recommendations for image improvement
- **Complete Privacy** - All AI processing performed locally on your device

### 🔒 **Privacy & Security**
- **No internet required** - works completely offline
- **No data collection** or tracking
- **App Sandbox** enabled for maximum security
- **Security-scoped bookmarks** for persistent folder access
- Only accesses folders you explicitly select
- **Memory-safe** with intelligent cache management

## 💻 System Requirements

- **Operating System**: macOS 12.0 (Monterey) or later
- **Architecture**: Universal Binary (Intel and Apple Silicon)
- **Memory**: Minimum 4GB RAM (8GB recommended for large image collections)
- **Storage**: 50MB for application installation
- **Privileges**: Standard user account (no admin privileges required)

## 📦 Installation

### Mac App Store (Recommended)
Download from the [Mac App Store](https://apps.apple.com/us/app/stillview-image-viewer/id6749210445) for automatic updates and sandboxed security.

### Building from Source
```bash
git clone https://github.com/vscarpenter/SimpleImageViewer.git
cd SimpleImageViewer
open "StillView - Simple Image Viewer.xcodeproj"
# Build and run in Xcode (⌘+R)
```

### Quick Start Guide
1. **Launch StillView** and grant folder access permissions
2. **Select a folder** containing images using the file picker
3. **Navigate images** with arrow keys or on-screen controls
4. **View thumbnails** by pressing **T** (strip) or **G** (grid)
5. **Start slideshow** with **S** key
6. **Access help** anytime with **⌘?**

## 🏗️ Architecture Overview

StillView implements a clean **MVVM (Model-View-ViewModel)** architecture with protocol-oriented design, leveraging SwiftUI's reactive paradigms and Combine framework for state management.

### Project Structure
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
│   ├── ImageMemoryManager.swift       # Cache size optimization
│   └── ImageViewerError.swift         # Custom error types
├── ViewModels/            # MVVM view models with reactive bindings
│   ├── ImageViewerViewModel.swift     # Main image viewer state
│   └── FolderSelectionViewModel.swift # Folder selection logic
├── Views/                 # SwiftUI user interface components
│   ├── ImageDisplayView.swift         # Core image rendering
│   ├── FolderSelectionView.swift      # Initial folder picker
│   ├── NavigationControlsView.swift   # Image navigation UI
│   ├── NotificationView.swift         # Toast notifications
│   └── ImageInfoOverlayView.swift     # Metadata display
├── Services/              # Business logic and system integration
│   ├── FileSystemService.swift        # File operations and monitoring
│   ├── ImageLoaderService.swift       # Async image loading
│   ├── KeyboardHandler.swift          # Global keyboard shortcuts
│   ├── ErrorHandlingService.swift     # Centralized error management
│   ├── SecurityScopedAccessManager.swift # Sandbox permissions
│   └── ImageMetadataService.swift     # EXIF data extraction
├── Extensions/            # Utility extensions and helpers
│   ├── UTType+ImageSupport.swift      # Image format detection
│   ├── Bundle+Resources.swift         # Resource loading
│   └── Color+Adaptive.swift           # Theme-aware colors
└── Documentation/         # Internal technical documentation
    └── KeyboardNavigation.md          # Keyboard system details
```

### Architectural Patterns

#### 1. MVVM with Combine
- **ViewModels** manage application state using `@Published` properties
- **Views** reactively update through SwiftUI's data binding
- **Models** represent pure data structures with business logic
- **Combine** publishers handle asynchronous operations and state changes

#### 2. Protocol-Oriented Design
```swift
protocol FileSystemService {
    func scanFolder(_ url: URL, recursive: Bool) async throws -> [ImageFile]
    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never>
    func createSecurityScopedBookmark(for url: URL) -> Data?
}

protocol ImageLoaderService {
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error>
    func preloadImages(_ urls: [URL], maxCount: Int)
    func clearCache()
}
```

#### 3. Repository Pattern
- **Services** abstract external dependencies (file system, image loading)
- **Default implementations** provide concrete functionality
- **Protocol conformance** enables testing with mock objects

## 🔧 Core Components

### ImageViewerViewModel
**Primary state manager** for the image viewing experience.

```swift
class ImageViewerViewModel: ObservableObject {
    @Published var currentImage: NSImage?
    @Published var currentIndex: Int = 0
    @Published var totalImages: Int = 0
    @Published var zoomLevel: Double = 1.0
    @Published var viewMode: ViewMode = .normal
    @Published var isSlideshow: Bool = false
}
```

**Key Responsibilities:**
- Image navigation state management
- Zoom and view mode controls
- Slideshow functionality
- Memory-efficient image caching
- Error handling and user feedback

### FileSystemService
**Handles all file system operations** with security-scoped access.

```swift
protocol FileSystemService {
    func scanFolder(_ url: URL, recursive: Bool) async throws -> [ImageFile]
    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never>
    func createSecurityScopedBookmark(for url: URL) -> Data?
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL?
}
```

**Features:**
- Asynchronous folder scanning with recursive support
- Real-time folder monitoring using DispatchSource
- Security-scoped bookmark management for sandbox compliance
- Comprehensive error handling with custom error types

### ImageLoaderService
**Optimized image loading** with memory management.

```swift
class DefaultImageLoaderService: ImageLoaderService {
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error>
    func preloadImages(_ urls: [URL], maxCount: Int)
    func clearCache()
}
```

**Capabilities:**
- ImageIO-based loading for optimal performance
- Intelligent memory pressure monitoring
- Background preloading of adjacent images
- Automatic cache management with configurable limits
- Large image handling with size-based optimizations

### KeyboardHandler
**Global keyboard navigation** system with AppKit integration.

```swift
class KeyboardHandler {
    func handleKeyPress(_ event: NSEvent) -> Bool
    private func setupKeyboardMapping()
}
```

**Supported Actions:**
- Navigation: Arrow keys, Page Up/Down, Home/End, Spacebar
- Zoom: +/-, 0 (fit), 1 (actual size)
- Mode: F (fullscreen), T (thumbnails), G (grid), S (slideshow)
- Information: I (image info), ⌘? (help)

### SecurityScopedAccessManager
**App Sandbox compliance** with persistent folder access.

```swift
class SecurityScopedAccessManager {
    func requestAccess(to url: URL) -> Bool
    func ensureAccess(to url: URL) -> Bool
    func createBookmark(for url: URL) -> Data?
    func resolveBookmark(_ data: Data) -> URL?
}
```

**Security Features:**
- Automatic bookmark creation and resolution
- Resource lifecycle management
- Memory-efficient access tracking
- Graceful permission request handling

## 🖼️ Supported Image Formats

StillView provides comprehensive support for modern and legacy image formats through the `UTType+ImageSupport` extension.

### Primary Formats (Full Support)
| Format | Extensions | Features | Performance |
|--------|------------|----------|-------------|
| **JPEG** | `.jpg`, `.jpeg` | EXIF metadata, progressive loading | Excellent |
| **PNG** | `.png` | Transparency, lossless compression | Excellent |
| **GIF** | `.gif` | Animation support, transparency | Good |
| **HEIF/HEIC** | `.heif`, `.heic` | Apple's high-efficiency format | Excellent |
| **WebP** | `.webp` | Google's modern format, animation | Good |

### Extended Formats (Basic Support)
| Format | Extensions | Features | Notes |
|--------|------------|----------|-------|
| **TIFF** | `.tiff`, `.tif` | High quality, multiple pages | Large files |
| **BMP** | `.bmp` | Uncompressed bitmap | Legacy support |
| **SVG** | `.svg` | Vector graphics, scalable | Basic rendering |

### Format Detection
```swift
extension UTType {
    static let supportedImageTypes: [UTType] = [
        .jpeg, .png, .gif, .heif, .heic, .webP, .tiff, .bmp, .svg
    ]
    
    var isSupportedImageType: Bool {
        return UTType.supportedImageTypes.contains { supportedType in
            self.conforms(to: supportedType)
        }
    }
}
```

## 🔒 Security & Privacy

StillView implements comprehensive security measures for App Store compliance and user privacy protection.

### App Sandbox Entitlements
```xml
<!-- Simple_Image_Viewer.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

### Security-Scoped Resource Access
```swift
// Persistent folder access across app launches
func createSecurityScopedBookmark(for url: URL) -> Data? {
    return try? url.bookmarkData(
        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
}

func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL? {
    let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope, .withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )
    return url?.startAccessingSecurityScopedResource() == true ? url : nil
}
```

### Privacy Guarantees
- **No network access** - operates completely offline
- **No data collection** - no analytics or telemetry
- **User-controlled access** - only reads user-selected folders
- **Memory protection** - automatic cleanup of cached images
- **Secure bookmarks** - encrypted folder access tokens

## ⌨️ Keyboard Navigation

Comprehensive keyboard shortcuts for efficient image browsing without mouse interaction.

### Navigation Commands
| Key | Action | Description |
|-----|--------|-------------|
| `←` / `→` | Previous/Next Image | Navigate through image sequence |
| `Space` | Next Image | Alternative next image key |
| `Page Up` / `Page Down` | Previous/Next Image | Page-based navigation |
| `Home` | First Image | Jump to beginning of collection |
| `End` | Last Image | Jump to end of collection |

### Zoom & View Controls
| Key | Action | Description |
|-----|--------|-------------|
| `+` / `=` | Zoom In | Increase image magnification |
| `-` | Zoom Out | Decrease image magnification |
| `0` | Fit to Window | Auto-size image to fit window |
| `1` | Actual Size | Display image at 100% scale |
| `F` / `Enter` | Toggle Fullscreen | Enter/exit fullscreen mode |
| `Escape` | Exit Fullscreen | Return to windowed mode |

### View Modes & Information
| Key | Action | Description |
|-----|--------|-------------|
| `T` | Thumbnail Strip | Show horizontal thumbnail navigation |
| `G` | Grid View | Display full-screen thumbnail grid |
| `S` | Slideshow | Start/stop automatic image progression |
| `I` | Image Info | Toggle metadata and EXIF overlay |
| `⌘?` | Help System | Open comprehensive help documentation |

### Implementation Details
The keyboard system uses AppKit's `NSEvent` handling wrapped in SwiftUI for reliable key capture:

```swift
// KeyCaptureViewRepresentable.swift
struct KeyCaptureViewRepresentable: NSViewRepresentable {
    let onKeyPress: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyPress = onKeyPress
        return view
    }
}

// KeyboardHandler.swift
func handleKeyPress(_ event: NSEvent) -> Bool {
    switch event.keyCode {
    case 123: // Left arrow
        imageViewerViewModel?.previousImage()
        return true
    case 124: // Right arrow
        imageViewerViewModel?.nextImage()
        return true
    // ... additional key mappings
    }
}
```

## 📚 API Documentation

### Core Models

#### ImageFile
Represents an image file with comprehensive metadata.

```swift
struct ImageFile: Identifiable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let type: UTType
    let size: Int64
    let creationDate: Date
    let modificationDate: Date
    
    // Computed properties
    var displayName: String { /* filename without extension */ }
    var formattedSize: String { /* human-readable file size */ }
    var formatDescription: String { /* user-friendly format name */ }
    var isAnimated: Bool { /* true for GIF files */ }
    var isVectorImage: Bool { /* true for SVG files */ }
    var isHighEfficiencyFormat: Bool { /* true for HEIF/HEIC/WebP */ }
}
```

#### FolderContent
Container for folder scanning results with navigation state.

```swift
struct FolderContent {
    let folderURL: URL
    let imageFiles: [ImageFile]
    let currentIndex: Int
    
    var hasImages: Bool { !imageFiles.isEmpty }
    var totalImages: Int { imageFiles.count }
    var currentImageFile: ImageFile? { /* safely access current image */ }
}
```

### Service Protocols

#### FileSystemService
File system operations with security-scoped access.

```swift
protocol FileSystemService {
    func scanFolder(_ url: URL, recursive: Bool) async throws -> [ImageFile]
    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never>
    func createSecurityScopedBookmark(for url: URL) -> Data?
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL?
    func isSupportedImageFile(_ url: URL) -> Bool
    func getFileType(for url: URL) -> UTType?
}
```

#### ImageLoaderService
Asynchronous image loading with caching and memory management.

```swift
protocol ImageLoaderService {
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error>
    func preloadImage(from url: URL)
    func cancelLoading(for url: URL)
    func clearCache()
    func preloadImages(_ urls: [URL], maxCount: Int)
}
```

### Error Handling

#### Custom Error Types
```swift
enum FileSystemError: LocalizedError {
    case folderAccessDenied
    case folderNotFound
    case noImagesFound
    case scanningFailed(Error)
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
}

enum ImageLoaderError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case corruptedImage
    case insufficientMemory
    case loadingCancelled
}
```

### Memory Management

#### ImageMemoryManager
Intelligent memory management with pressure monitoring.

```swift
class ImageMemoryManager {
    private let maxCacheSize: Int64 = 1_073_741_824 // 1GB default
    private var currentCacheSize: Int64 = 0
    
    func shouldLoadImage(size: Int64) -> Bool
    func didLoadImage(size: Int64)
    func didRemoveImage(size: Int64)
    func handleMemoryPressure()
}
```

## 🧪 Testing

StillView includes a comprehensive test suite covering all major components and functionality.

### Running Tests
```bash
# Command line (using xcodebuild)
xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer"

# In Xcode
# Method 1: ⌘+U (run all tests)
# Method 2: Use Test Navigator (⌘+6) for selective testing
# Method 3: Right-click specific test classes and select "Run Tests"
```

### Test Structure
```
StillView - Simple Image Viewer Tests/
├── Models/
│   ├── ImageFileTests.swift              # Image file model validation
│   ├── FolderContentTests.swift          # Folder content handling
│   ├── ImageCacheTests.swift             # Cache functionality
│   └── ImageMemoryManagerTests.swift     # Memory management logic
├── ViewModels/
│   ├── ImageViewerViewModelTests.swift   # Main view model state
│   └── FolderSelectionViewModelTests.swift # Folder selection logic
├── Services/
│   ├── FileSystemServiceTests.swift      # File operations (unit)
│   ├── FileSystemServiceIntegrationTests.swift # File operations (integration)
│   ├── ImageLoaderServiceTests.swift     # Image loading logic
│   ├── KeyboardHandlerTests.swift        # Keyboard navigation
│   └── ErrorHandlingServiceTests.swift   # Error management
├── Extensions/
│   ├── UTTypeImageSupportTests.swift     # Image format detection
│   └── ColorAdaptiveTests.swift          # Theme adaptation
└── Views/
    └── FolderSelectionViewTests.swift    # UI component tests
```

### Test Coverage Areas

#### Unit Tests
- **Model Validation**: ImageFile creation, metadata extraction
- **Service Logic**: File scanning, image loading, keyboard handling
- **Memory Management**: Cache limits, pressure handling
- **Error Handling**: Custom error types, user feedback
- **Format Support**: Image type detection, UTType extensions

#### Integration Tests
- **Security-Scoped Access**: Bookmark creation and resolution
- **File System Monitoring**: Real-time folder change detection
- **Image Loading Pipeline**: End-to-end image processing
- **Memory Pressure**: System integration and cleanup

#### Mock Objects
```swift
// Example mock for testing
class MockImageLoaderService: ImageLoaderService {
    var loadImageCallCount = 0
    var preloadImageCallCount = 0
    var clearCacheCallCount = 0
    
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error> {
        loadImageCallCount += 1
        return Just(NSImage()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}
```

### Performance Testing
- **Memory Usage**: Verify cache limits and cleanup
- **Loading Times**: Measure image loading performance
- **UI Responsiveness**: Ensure smooth navigation
- **Resource Cleanup**: Check for memory leaks

## 🛠️ Development Setup

### Prerequisites
- **Xcode 15.0+** (for SwiftUI and latest Swift features)
- **macOS 14.0+** (for development, runs on macOS 12.0+)
- **Apple Developer Account** (for code signing and App Store distribution)

### Development Environment Setup
```bash
# Clone the repository
git clone https://github.com/vscarpenter/SimpleImageViewer.git
cd SimpleImageViewer

# Open in Xcode
open "StillView - Simple Image Viewer.xcodeproj"

# Alternative: Open from command line
xed .
```

### Project Configuration
1. **Bundle Identifier**: `com.vinny.StillView-Simple-Image-Viewer`
2. **Deployment Target**: macOS 12.0
3. **Swift Version**: Swift 5.0+
4. **Build System**: New Build System (Xcode 10+)

### Development Workflow

#### 1. Code Organization
- Follow the existing MVVM architecture
- Place new services in `Services/` directory
- Use protocol-oriented design for testability
- Implement proper error handling with custom error types

#### 2. SwiftUI Best Practices
```swift
// Use @StateObject for view model ownership
@StateObject private var viewModel = ImageViewerViewModel()

// Use @ObservedObject for passed view models
@ObservedObject var viewModel: ImageViewerViewModel

// Prefer @Published for reactive state
@Published var currentImage: NSImage?

// Use proper accessibility labels
.accessibilityLabel("Image \(index + 1) of \(total)")
```

#### 3. Memory Management
```swift
// Use weak references in closures
.sink { [weak self] value in
    self?.handleValue(value)
}

// Implement proper cleanup
deinit {
    cancellables.forEach { $0.cancel() }
    stopAccessingSecurityScopedResource()
}
```

#### 4. Security Considerations
- Always use security-scoped bookmarks for persistent access
- Handle bookmark staleness and re-request access when needed
- Implement proper resource lifecycle management
- Follow App Sandbox guidelines strictly

### Build Configurations

#### Debug Configuration
- Enable all debugging symbols
- Disable optimizations for debugging
- Include debug logging and assertions
- Use development provisioning profile

#### Release Configuration
- Enable full optimizations (`-O`)
- Strip debugging symbols for App Store
- Use distribution provisioning profile
- Enable Link-Time Optimization (LTO)

### Code Signing & Distribution
```bash
# Development builds
xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" \
           -scheme "StillView - Simple Image Viewer" \
           -configuration Debug \
           build

# App Store distribution
xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" \
           -scheme "StillView - Simple Image Viewer" \
           -configuration Release \
           -archivePath "StillView.xcarchive" \
           archive
```

## 🤝 Contributing

We welcome contributions from the community! Please follow these guidelines to ensure smooth collaboration.

### Getting Started
1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create a branch** for your feature or bug fix
4. **Make your changes** following the coding standards
5. **Test thoroughly** using the provided test suite
6. **Submit a pull request** with a clear description

### Contribution Guidelines

#### Code Standards
- **Swift Style**: Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Documentation**: Document all public APIs with proper Swift documentation comments
- **Testing**: Include unit tests for new functionality
- **Accessibility**: Ensure all UI elements are accessible with VoiceOver

#### Commit Messages
Use conventional commit format:
```
feat: add thumbnail grid view functionality
fix: resolve memory leak in image cache
docs: update API documentation for ImageLoaderService
test: add unit tests for keyboard navigation
```

#### Pull Request Process
1. **Create Issue**: For major changes, create an issue first to discuss
2. **Branch Naming**: Use descriptive branch names (`feature/thumbnail-navigation`, `fix/memory-leak`)
3. **Test Coverage**: Ensure new code has appropriate test coverage
4. **Documentation**: Update README and inline documentation as needed
5. **Code Review**: Address all feedback before merging

### Areas for Contribution

#### High Priority
- **Performance Optimizations**: Image loading and memory usage improvements
- **Accessibility Enhancements**: VoiceOver support and keyboard navigation
- **Format Support**: Additional image format support (AVIF, JXL)
- **User Experience**: UI/UX improvements and usability enhancements

#### Medium Priority
- **Internationalization**: Multi-language support
- **Customization**: User preferences and settings
- **Integration**: System integration improvements
- **Documentation**: Additional guides and examples

#### Bug Reports
When reporting bugs, please include:
- **macOS Version**: System version and hardware details
- **Steps to Reproduce**: Clear reproduction steps
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Screenshots**: Visual evidence if applicable
- **Console Output**: Any relevant log messages

### Development Resources
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Combine Framework Guide](https://developer.apple.com/documentation/combine/)
- [App Sandbox Design Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos/)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author & Support

**Vinny Carpenter**  
🌐 Website: [https://vinny.dev](https://vinny.dev)  
🐙 GitHub: [@vscarpenter](https://github.com/vscarpenter)  
📧 Support: Create an [issue](https://github.com/vscarpenter/SimpleImageViewer/issues) for bug reports or feature requests

---

**StillView - Simple Image Viewer** - Elegant, secure, and accessible image browsing for macOS  
Built with SwiftUI • Comprehensive Architecture • Developer-Friendly Documentation  
Created with ❤️ by [Vinny Carpenter](https://vinny.dev)

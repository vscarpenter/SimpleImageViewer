# StillView - Simple Image Viewer
## Product Requirements Document (PRD)

**Version:** 2.5.0
**Last Updated:** October 7, 2025
**Status:** Active Development
**Target Platform:** macOS 12.0+ (Monterey), Optimized for macOS 26.0+

---

## 1. Executive Summary

### 1.1 Product Vision
StillView is a minimalist, elegant image viewer designed for macOS users who demand a clean, distraction-free way to browse image collections with advanced AI-powered analysis capabilities. The application combines simplicity with cutting-edge on-device AI to provide intelligent image understanding while maintaining complete user privacy.

### 1.2 Product Positioning
- **Primary Market**: macOS users seeking a lightweight, keyboard-first image viewer
- **Secondary Market**: Photographers, designers, and creative professionals requiring AI-powered image analysis
- **Distribution**: Mac App Store with full App Sandbox compliance
- **Differentiation**: Native macOS experience with on-device AI analysis and zero data collection

### 1.3 Success Metrics
- User adoption rate on Mac App Store
- Session duration and daily active users
- AI feature adoption rate (macOS 26+ users)
- User retention at 7, 30, and 90 days
- App Store rating and review sentiment
- Performance metrics (memory usage, loading speed)

---

## 2. Product Overview

### 2.1 Core Value Propositions

#### For All Users
1. **Effortless Browsing**: Browse entire folders with intuitive keyboard shortcuts
2. **Privacy First**: No internet required, no data collection, complete offline operation
3. **Universal Format Support**: Support for JPEG, PNG, GIF, HEIF/HEIC, WebP, TIFF, BMP, SVG
4. **macOS Native**: Full VoiceOver support, high contrast mode, reduced motion preferences

#### For macOS 26+ Users
5. **AI-Powered Analysis**: On-device image classification, object detection, scene understanding
6. **Smart Organization**: Automatically generated tags and smart categorization
7. **Enhanced Accessibility**: AI-generated image descriptions for VoiceOver
8. **Quality Assessment**: Automated evaluation of image sharpness, exposure, technical quality

### 2.2 Target Audience

#### Primary Personas

**1. Alex - The Minimalist User**
- Age: 28-45
- Occupation: Knowledge worker, creative professional
- Goals: Quick, distraction-free image viewing
- Pain Points: Bloated software with unnecessary features
- Key Needs: Keyboard navigation, fast performance, clean interface

**2. Jordan - The Photographer**
- Age: 25-55
- Occupation: Professional/amateur photographer
- Goals: Quickly review and organize large photo collections
- Pain Points: Slow loading, poor organization tools
- Key Needs: Fast navigation, metadata viewing, quality assessment

**3. Sam - The Accessibility User**
- Age: Any
- Occupation: Various
- Goals: Accessible image viewing experience
- Pain Points: Poor screen reader support in image viewers
- Key Needs: VoiceOver support, high contrast, AI-generated descriptions

### 2.3 Key Features Summary

| Feature Category | Description | Availability |
|-----------------|-------------|--------------|
| **Core Viewing** | Image display, navigation, zoom controls | All macOS 12.0+ |
| **Keyboard Navigation** | Comprehensive keyboard shortcuts | All macOS 12.0+ |
| **View Modes** | Normal, Thumbnail Strip, Grid View | All macOS 12.0+ |
| **Slideshow** | Automatic image progression | All macOS 12.0+ |
| **AI Analysis** | Image classification, object detection, scene understanding | macOS 26.0+ |
| **Smart Tags** | AI-generated categorization | macOS 26.0+ |
| **Quality Assessment** | Automated image quality evaluation | macOS 26.0+ |
| **Enhanced Accessibility** | AI-powered image descriptions | macOS 26.0+ |

---

## 3. Functional Requirements

### 3.1 Core Image Viewing

#### FR-1: Folder Selection and Scanning
**Priority**: P0 (Critical)
**User Story**: As a user, I want to select a folder and view all supported images within it.

**Acceptance Criteria**:
- User can select folders via native macOS file picker
- System scans folder recursively (configurable)
- Supports security-scoped bookmarks for persistent access
- Real-time folder monitoring for changes
- Displays loading progress during scan
- Handles errors gracefully (permissions, empty folders)

**Technical Requirements**:
- App Sandbox compliant with `com.apple.security.files.user-selected.read-write`
- Security-scoped bookmark creation and resolution
- Asynchronous folder scanning with progress reporting
- Support for 10,000+ images per folder

#### FR-2: Image Display and Rendering
**Priority**: P0 (Critical)
**User Story**: As a user, I want to view images with high quality and smooth performance.

**Acceptance Criteria**:
- Supports JPEG, PNG, GIF (animated), HEIF/HEIC, WebP, TIFF, BMP, SVG
- Images render at native resolution when zoomed to actual size
- Smooth zoom transitions with pinch gesture support
- Automatic fit-to-window on initial load
- Memory-efficient rendering for large images (20MB+)
- Preserves aspect ratio in all zoom modes

**Technical Requirements**:
- ImageIO framework for optimal loading performance
- Metal acceleration where available
- Maximum memory per image: 100MB
- Target render time: <100ms for images under 10MB

#### FR-3: Navigation Controls
**Priority**: P0 (Critical)
**User Story**: As a user, I want to navigate through images quickly using keyboard or UI controls.

**Acceptance Criteria**:
- Arrow keys navigate previous/next
- Page Up/Down for previous/next
- Home/End for first/last image
- Spacebar for next image
- On-screen navigation buttons visible and accessible
- Image counter displays current position (e.g., "5 of 120")
- Circular navigation (optional, configurable)

**Technical Requirements**:
- Key event handling via AppKit NSEvent
- Preload adjacent images (previous + next 2)
- Navigation response time: <50ms
- Smooth image transitions with configurable animation

### 3.2 View Modes and Interface

#### FR-4: Thumbnail Strip View
**Priority**: P1 (High)
**User Story**: As a user, I want to see thumbnails of nearby images for quick navigation.

**Acceptance Criteria**:
- Horizontal thumbnail strip at bottom of window
- Shows current image + 10 adjacent images (5 before, 5 after)
- Thumbnails highlight current selection
- Click thumbnail to jump to image
- Smooth scrolling as user navigates
- Keyboard shortcut 'T' toggles strip

**Technical Requirements**:
- Thumbnail generation: 150x150px at 72 DPI
- Lazy loading of thumbnails (only visible ones)
- Maximum 20 thumbnails in memory simultaneously
- Thumbnail generation time: <100ms per image

#### FR-5: Grid View
**Priority**: P1 (High)
**User Story**: As a user, I want to view all images in a grid layout for better overview.

**Acceptance Criteria**:
- Full-screen grid of thumbnails
- Responsive grid (adapts to window size)
- Double-click or Enter to open image in normal view
- Smooth zoom-in/out transitions
- Keyboard navigation within grid
- Grid shortcut 'G' toggles view
- Search/filter functionality

**Technical Requirements**:
- Responsive layout: 3-8 columns based on window width
- Thumbnail size: 200x200px at 72 DPI
- Skeleton loading states for thumbnails
- Virtual scrolling for collections over 100 images
- Grid rendering performance: 60fps

#### FR-6: Slideshow Mode
**Priority**: P2 (Medium)
**User Story**: As a user, I want to automatically cycle through images hands-free.

**Acceptance Criteria**:
- Configurable interval (1-10 seconds, default 3s)
- Smooth cross-fade transitions
- Keyboard shortcut 'S' starts/stops slideshow
- Spacebar pauses/resumes during slideshow
- On-screen timer/progress indicator
- Exit slideshow with Escape or any navigation key

**Technical Requirements**:
- Timer-based automatic progression
- Cross-fade duration: 300ms
- Continues during folder scanning
- Respect system reduced-motion preferences

### 3.3 Zoom and Display Controls

#### FR-7: Zoom Functionality
**Priority**: P0 (Critical)
**User Story**: As a user, I want precise control over image zoom levels.

**Acceptance Criteria**:
- Zoom levels: 10%, 25%, 50%, 100%, 150%, 200%, 400%, 800%
- '+' to zoom in, '-' to zoom out
- '0' to fit image to window
- '1' to show actual size (100%)
- Pinch gesture support on trackpad
- Zoom centers on mouse cursor position
- Smooth zoom animations

**Technical Requirements**:
- Zoom increment: 25% per step
- Minimum zoom: 10%, Maximum zoom: 800%
- Smooth zoom animation: 200ms
- Maintain zoom level when navigating (optional, configurable)

#### FR-8: Fullscreen Mode
**Priority**: P1 (High)
**User Story**: As a user, I want immersive fullscreen viewing.

**Acceptance Criteria**:
- 'F' or 'Enter' toggles fullscreen
- Escape exits fullscreen
- Toolbar auto-hides in fullscreen (shows on mouse move)
- All navigation controls available in fullscreen
- Respects macOS native fullscreen behavior

**Technical Requirements**:
- Uses macOS native fullscreen APIs
- Toolbar auto-hide delay: 2 seconds
- Smooth transition: 300ms
- Support for multiple displays

### 3.4 AI-Powered Features (macOS 26.0+)

#### FR-9: Image Classification
**Priority**: P1 (High, macOS 26+ only)
**User Story**: As a user, I want the app to automatically identify what's in my images.

**Acceptance Criteria**:
- Identifies primary subject (person, animal, object, scene)
- Provides confidence scores for classifications
- Uses ResNet50 Core ML model with Vision framework fallback
- Analysis completes in 1-2 seconds
- Results cached for instant retrieval
- Works completely offline

**Technical Requirements**:
- Primary: ResNet50 Core ML model (bundled)
- Fallback: VNClassifyImageRequest (system)
- Minimum confidence threshold: 60%
- Cache up to 20 recent analyses
- Background processing on dedicated queue
- Maximum analysis time: 3 seconds

#### FR-10: Object Detection
**Priority**: P1 (High, macOS 26+ only)
**User Story**: As a user, I want to see all objects detected in my images.

**Acceptance Criteria**:
- Detects people, animals, objects with bounding boxes
- Provides confidence scores per object
- Categorizes objects by type
- Shows count of detected items
- Highlights primary subject
- Face detection and recognition

**Technical Requirements**:
- Uses VNRecognizeAnimalsRequest, VNDetectHumanRectanglesRequest
- Minimum object confidence: 50%
- Maximum 20 objects per image
- Bounding box overlay (optional visualization)
- Processing time: <500ms per image

#### FR-11: Scene Classification
**Priority**: P2 (Medium, macOS 26+ only)
**User Story**: As a user, I want to understand the context and setting of my images.

**Acceptance Criteria**:
- Classifies indoor/outdoor scenes
- Identifies lighting conditions (bright, dim, backlit)
- Detects setting type (beach, mountain, city, etc.)
- Provides scene confidence scores
- Displays top 3 scene classifications

**Technical Requirements**:
- Uses VNClassifyImageRequest with scene taxonomy
- Minimum confidence: 40%
- Top 3 results returned
- Processing time: <300ms

#### FR-12: Text Recognition (OCR)
**Priority**: P2 (Medium, macOS 26+ only)
**User Story**: As a user, I want to extract text from images.

**Acceptance Criteria**:
- Detects all readable text in image
- Provides bounding boxes for text regions
- Supports multiple languages
- Shows confidence per text block
- Allows text selection and copying
- Handles rotated and skewed text

**Technical Requirements**:
- Uses VNRecognizeTextRequest with accurate recognition
- Language support: English, Spanish, French, German, Chinese, Japanese
- Minimum text confidence: 60%
- Maximum 50 text regions per image
- Processing time: <1 second

#### FR-13: Image Quality Assessment
**Priority**: P1 (High, macOS 26+ only)
**User Story**: As a user, I want automated quality assessment of my images.

**Acceptance Criteria**:
- Evaluates sharpness/focus quality
- Assesses exposure (over/under exposed)
- Checks image resolution and dimensions
- Detects blur and noise
- Provides quality score (0-100)
- Suggests improvements

**Technical Requirements**:
- Custom image quality algorithms using Core Image
- Blur detection: Laplacian variance method
- Exposure analysis: Histogram analysis
- Resolution assessment: Pixel density check
- Processing time: <200ms

#### FR-14: Smart Tags and Categorization
**Priority**: P1 (High, macOS 26+ only)
**User Story**: As a user, I want automatically generated tags for my images.

**Acceptance Criteria**:
- Generates 3-10 relevant tags per image
- Categories: People, Objects, Scenes, Colors, Activities
- Tags ranked by relevance
- Supports tag-based search
- Tags persist across sessions
- Manual tag editing capability

**Technical Requirements**:
- Tags derived from classification, object detection, scene analysis
- Natural language processing for tag generation
- Tag relevance scoring algorithm
- Storage: JSON format in UserDefaults
- Maximum 15 tags per image

#### FR-15: AI-Generated Image Descriptions
**Priority**: P1 (High, macOS 26+ only)
**User Story**: As a VoiceOver user, I want rich AI-generated descriptions of images.

**Acceptance Criteria**:
- Generates 1-2 sentence natural language descriptions
- Describes main subject, setting, and notable details
- Optimized for screen reader clarity
- Multi-language support
- Fallback to basic metadata if AI unavailable
- Description length: 50-150 characters

**Technical Requirements**:
- NaturalLanguage framework for text generation
- Template-based description with AI data
- Caching of descriptions
- Accessibility-optimized phrasing
- Generation time: <500ms

### 3.5 User Preferences and Customization

#### FR-16: Comprehensive Preferences System
**Priority**: P1 (High)
**User Story**: As a user, I want to customize the app behavior to my preferences.

**Acceptance Criteria**:
- Tabbed preferences window (General, Appearance, Keyboard)
- Live preview of changes
- Reset to defaults option
- Settings persist across launches
- Import/export settings capability
- Validation with user feedback

**Categories**:
- **General**: Slideshow interval, zoom behavior, folder scan options
- **Appearance**: Theme, glassmorphism, animations, toolbar style
- **Keyboard**: Customizable shortcuts with conflict detection

**Technical Requirements**:
- UserDefaults storage with KVO
- JSON export/import for settings
- Real-time validation
- Migration support for settings versions

#### FR-17: Keyboard Shortcut Customization
**Priority**: P2 (Medium)
**User Story**: As a power user, I want to customize keyboard shortcuts.

**Acceptance Criteria**:
- Record new shortcuts with intuitive interface
- Conflict detection and warnings
- Export/import shortcut schemes
- Reset to default shortcuts
- Visual shortcuts reference (⌘?)
- Support for modifier keys (⌘, ⌥, ⌃, ⇧)

**Technical Requirements**:
- Shortcut recorder component
- Conflict resolution algorithm
- Plist-based storage
- System shortcut collision detection

#### FR-18: Appearance Customization
**Priority**: P2 (Medium)
**User Story**: As a user, I want to customize the visual appearance.

**Acceptance Criteria**:
- Light/Dark/Auto theme selection
- Glassmorphism effect intensity (0-100%)
- Animation speed control (Off, Reduced, Normal, Fast)
- Hover effect toggle
- Toolbar style options (Compact, Regular, Large)
- Thumbnail quality settings

**Technical Requirements**:
- NSAppearance API for theming
- Core Animation for effects
- Respect system accessibility preferences
- Performance impact: <5% CPU for effects

### 3.6 Accessibility Features

#### FR-19: VoiceOver Support
**Priority**: P0 (Critical)
**User Story**: As a VoiceOver user, I want complete access to all functionality.

**Acceptance Criteria**:
- All UI elements have accessibility labels
- Image descriptions (with AI enhancement on macOS 26+)
- Keyboard navigation fully supported
- Status announcements (loading, navigation)
- Accessibility hints for complex controls
- Rotor support for quick navigation

**Technical Requirements**:
- NSAccessibility protocol compliance
- Dynamic accessibility labels
- Announcement notifications
- Custom accessibility actions
- WCAG 2.1 AA compliance

#### FR-20: High Contrast and Reduced Motion
**Priority**: P1 (High)
**User Story**: As a user with visual sensitivity, I want the app to respect my system preferences.

**Acceptance Criteria**:
- Detects and respects high contrast mode
- Respects reduced motion preferences
- Adjustable contrast in preferences
- Disable all animations option
- Focus indicators always visible in high contrast

**Technical Requirements**:
- NSWorkspace.shared accessibility notifications
- Conditional animation rendering
- High contrast color palette
- Focus ring enhancement in high contrast mode

### 3.7 Help and Documentation

#### FR-21: Comprehensive Help System
**Priority**: P1 (High)
**User Story**: As a user, I want easy access to help and documentation.

**Acceptance Criteria**:
- ⌘? opens help overlay
- Searchable keyboard shortcuts reference
- Getting started guide
- Tooltips on all controls
- Help menu with direct links to features
- Context-sensitive help

**Technical Requirements**:
- Markdown-based help content
- Help search index
- Overlay UI with blur background
- Deep linking to specific help topics

#### FR-22: What's New Feature
**Priority**: P2 (Medium)
**User Story**: As a user, I want to know about new features after updates.

**Acceptance Criteria**:
- Automatic display on version update
- Manual access via Help menu
- Highlights major features
- Images/GIFs demonstrating features
- Version-based content loading
- Dismissible with "Don't show again" option

**Technical Requirements**:
- JSON-based content (Resources/whats-new.json)
- Version tracking in UserDefaults
- Modal sheet presentation
- Image asset management

### 3.8 Performance and Memory Management

#### FR-23: Memory Management
**Priority**: P0 (Critical)
**User Story**: As a user, I want the app to handle large image collections without crashes.

**Acceptance Criteria**:
- Maximum memory usage: 1GB for cache
- Intelligent cache eviction (LRU strategy)
- Memory pressure monitoring
- Automatic cache cleanup
- Handles 10,000+ images in folder
- No memory leaks during extended use

**Technical Requirements**:
- NSCache for image storage
- DispatchSource for memory pressure
- Maximum simultaneous loads: 3 images
- Cache size: 50 images or 1GB, whichever is smaller
- Automatic cleanup at 80% memory threshold

#### FR-24: Loading Performance
**Priority**: P0 (Critical)
**User Story**: As a user, I want images to load quickly and smoothly.

**Acceptance Criteria**:
- Images under 10MB load in <500ms
- Progressive loading for large images
- Background preloading of adjacent images
- Loading indicators with progress
- Skeleton states during load
- Cancellation of unused loads

**Technical Requirements**:
- ImageIO incremental loading
- Background DispatchQueue for loading
- Preload buffer: 2 images before + 2 after
- Loading timeout: 10 seconds
- Cancel pending loads on navigation

---

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| App Launch Time | <1 second | <2 seconds |
| Image Load Time (10MB) | <500ms | <1 second |
| Image Load Time (50MB) | <2 seconds | <5 seconds |
| Navigation Response | <50ms | <100ms |
| UI Frame Rate | 60fps | 30fps minimum |
| Memory Usage (Idle) | <100MB | <200MB |
| Memory Usage (Active) | <500MB | <1GB |
| Thumbnail Generation | <100ms | <300ms |
| AI Analysis Time | <2 seconds | <5 seconds |

### 4.2 Security and Privacy

#### Privacy Requirements
- **No Network Access**: Complete offline operation
- **No Data Collection**: Zero telemetry or analytics
- **No User Tracking**: No identification or behavior tracking
- **Local Processing**: All AI processing on-device
- **Minimal Permissions**: Only user-selected folder access

#### Security Requirements
- **App Sandbox**: Full sandbox compliance
- **Code Signing**: Valid Apple Developer signature
- **Entitlements**: Minimal required entitlements only
  - `com.apple.security.app-sandbox` (required)
  - `com.apple.security.files.user-selected.read-write` (required)
  - `com.apple.security.files.bookmarks.app-scope` (required)
- **Secure Storage**: Security-scoped bookmarks for folder access
- **Resource Cleanup**: Proper lifecycle management

### 4.3 Compatibility Requirements

#### Platform Support
- **Minimum**: macOS 12.0 (Monterey)
- **Optimized**: macOS 26.0+ (Tahoe)
- **Architecture**: Universal Binary (Intel + Apple Silicon)
- **Display**: Standard DPI and Retina displays

#### AI Features Compatibility
- **Full AI Features**: macOS 26.0+ only
- **Graceful Degradation**: Core features work on macOS 12.0+
- **Feature Detection**: Runtime capability detection
- **User Communication**: Clear messaging about AI availability

### 4.4 Accessibility Requirements

- **VoiceOver**: Complete screen reader support
- **Keyboard Navigation**: Full keyboard-only operation
- **High Contrast**: Support for increased contrast modes
- **Reduced Motion**: Respect system animation preferences
- **Focus Indicators**: Always visible focus states
- **Text Size**: Support for Dynamic Type
- **Color Blindness**: Accessible color schemes
- **WCAG Compliance**: WCAG 2.1 AA minimum

### 4.5 Localization Requirements

#### Initial Release (English Only)
- US English as primary language
- Localization-ready architecture
- Externalized strings using NSLocalizedString
- Date/number formatting using system locale

#### Future Localization
- Spanish, French, German, Japanese, Chinese (Simplified)
- RTL language support preparation
- AI features multi-language support

### 4.6 Quality Assurance Requirements

#### Testing Coverage
- Unit Tests: 70% code coverage minimum
- Integration Tests: Critical user flows
- UI Tests: Key interaction scenarios
- Performance Tests: Load time, memory usage
- Accessibility Tests: VoiceOver compliance

#### Test Categories
- **Smoke Tests**: Core functionality verification
- **Regression Tests**: Bug prevention
- **Performance Tests**: Memory and speed benchmarks
- **Security Tests**: Sandbox compliance, permission handling
- **Accessibility Tests**: VoiceOver, keyboard navigation
- **Compatibility Tests**: macOS version testing

---

## 5. Technical Architecture

### 5.1 Architecture Pattern
**MVVM (Model-View-ViewModel)** with protocol-oriented design

```
┌─────────────────────────────────────────────────┐
│                  Views (SwiftUI)                 │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────┐ │
│  │  Image   │ │  Folder  │ │   Thumbnail    │ │
│  │  Display │ │ Selection│ │      Grid      │ │
│  └──────────┘ └──────────┘ └─────────────────┘ │
└───────────────────────┬─────────────────────────┘
                        │ Bindings (@Published)
┌───────────────────────▼─────────────────────────┐
│            ViewModels (ObservableObject)         │
│  ┌──────────────────┐  ┌────────────────────┐  │
│  │ ImageViewerVM    │  │ FolderSelectionVM  │  │
│  │ - State mgmt     │  │ - Folder logic     │  │
│  │ - Navigation     │  │ - Recent folders   │  │
│  └──────────────────┘  └────────────────────┘  │
└───────────────────────┬─────────────────────────┘
                        │ Service Layer
┌───────────────────────▼─────────────────────────┐
│              Services (Protocols)                │
│  ┌──────────────┐ ┌────────────┐ ┌────────────┐│
│  │ FileSystem   │ │ImageLoader │ │ AI Analysis││
│  │  Service     │ │  Service   │ │  Service   ││
│  └──────────────┘ └────────────┘ └────────────┘│
└───────────────────────┬─────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────┐
│                 Models (Data)                    │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────┐ │
│  │ImageFile │ │  Folder  │ │ AnalysisResult │ │
│  │          │ │ Content  │ │                 │ │
│  └──────────┘ └──────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────┘
```

### 5.2 Core Components

#### Models
- **ImageFile**: Image file representation with metadata
- **FolderContent**: Folder scanning results
- **ImageCache**: Memory-managed image cache
- **ImageMemoryManager**: Memory pressure handling
- **ImageAnalysisResult**: AI analysis data structure

#### ViewModels
- **ImageViewerViewModel**: Main viewer state management
- **FolderSelectionViewModel**: Folder selection logic

#### Services
- **FileSystemService**: File operations, folder scanning
- **ImageLoaderService**: Async image loading with cache
- **AIImageAnalysisService**: AI-powered analysis (macOS 26+)
- **KeyboardHandler**: Global keyboard event handling
- **SecurityScopedAccessManager**: Sandbox permission management
- **PreferencesService**: User preferences storage

#### Views
- **ContentView**: Main application container
- **ImageDisplayView**: Core image rendering
- **FolderSelectionView**: Initial folder picker
- **NavigationControlsView**: Navigation UI
- **EnhancedThumbnailGridView**: Grid view with responsive layout
- **AIInsightsView**: AI analysis display panel
- **WhatsNewSheet**: Version update notifications

### 5.3 Technology Stack

#### Frameworks
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive state management
- **AppKit**: macOS native functionality
- **ImageIO**: High-performance image loading
- **Core ML**: Machine learning model inference
- **Vision**: Image analysis framework
- **VisionKit**: Document scanning and text recognition
- **NaturalLanguage**: Text processing and generation
- **Core Image**: Image processing and filters
- **UniformTypeIdentifiers**: File type detection

#### AI/ML Stack (macOS 26+)
- **ResNet50 Core ML Model**: Primary image classification (bundled)
- **Vision Framework**: Fallback classification, object detection
- **VNClassifyImageRequest**: Image and scene classification
- **VNRecognizeAnimalsRequest**: Animal detection
- **VNDetectHumanRectanglesRequest**: Human detection
- **VNRecognizeTextRequest**: OCR capabilities
- **Custom Quality Models**: Image quality assessment

### 5.4 Data Flow

#### Image Loading Flow
```
User Selects Folder
    ↓
SecurityScopedAccessManager requests access
    ↓
FileSystemService scans folder
    ↓
ImageFile models created
    ↓
ImageViewerViewModel updated
    ↓
ImageLoaderService loads current image
    ↓
PreloadService loads adjacent images
    ↓
ImageCache stores loaded images
    ↓
View displays image
```

#### AI Analysis Flow (macOS 26+)
```
Image Displayed
    ↓
AIImageAnalysisService triggered
    ↓
Check cache for existing analysis
    ↓
If not cached:
  - ResNet50 classification
  - Vision object detection
  - Scene classification
  - Text recognition (OCR)
  - Quality assessment
    ↓
Generate smart tags
    ↓
Create natural language description
    ↓
Cache results (LRU, max 20 entries)
    ↓
Update ViewModel
    ↓
AIInsightsView displays results
```

### 5.5 File Structure

```
StillView - Simple Image Viewer/
├── App/
│   ├── SimpleImageViewerApp.swift      # App entry point
│   ├── AppCoordinator.swift            # Navigation coordination
│   ├── AppDelegate.swift               # AppKit integration
│   ├── ContentView.swift               # Root view
│   └── WindowAccessor.swift            # Window management
│
├── Models/
│   ├── ImageFile.swift                 # Image file model
│   ├── FolderContent.swift             # Folder data
│   ├── ImageCache.swift                # Image caching
│   ├── ImageMemoryManager.swift        # Memory management
│   ├── ImageViewerError.swift          # Error types
│   ├── WhatsNewContent.swift           # What's New data
│   ├── ThumbnailQuality.swift          # Thumbnail settings
│   ├── WindowState.swift               # Window persistence
│   └── AIAnalysisError.swift           # AI error types
│
├── ViewModels/
│   ├── ImageViewerViewModel.swift      # Main ViewModel
│   └── FolderSelectionViewModel.swift  # Folder selection ViewModel
│
├── Views/
│   ├── ImageDisplayView.swift          # Core image display
│   ├── FolderSelectionView.swift       # Folder picker
│   ├── NavigationControlsView.swift    # Navigation UI
│   ├── EnhancedThumbnailGridView.swift # Grid view
│   ├── AIInsightsView.swift            # AI analysis panel
│   ├── WhatsNewSheet.swift             # Update notifications
│   ├── PreferencesSection.swift        # Preferences UI
│   ├── ErrorDialogView.swift           # Error presentation
│   └── NotificationView.swift          # Toast notifications
│
├── Services/
│   ├── FileSystemService.swift         # File operations
│   ├── ImageLoaderService.swift        # Image loading
│   ├── AIImageAnalysisService.swift    # AI analysis
│   ├── KeyboardHandler.swift           # Keyboard events
│   ├── SecurityScopedAccessManager.swift # Permissions
│   ├── PreferencesService.swift        # Settings storage
│   ├── WhatsNewService.swift           # What's New logic
│   ├── AccessibilityService.swift      # VoiceOver support
│   └── ErrorHandlingService.swift      # Error management
│
├── Extensions/
│   ├── UTType+ImageSupport.swift       # Image format support
│   ├── Color+Adaptive.swift            # Theme colors
│   ├── DesignTokens.swift              # Design system
│   ├── AnimationPresets.swift          # Animation configs
│   └── Bundle+Resources.swift          # Resource loading
│
├── Resources/
│   ├── whats-new.json                  # What's New content
│   ├── CoreMLModels/
│   │   └── Resnet50.mlmodel            # AI classification model
│   └── Assets.xcassets/                # Images and icons
│
└── Documentation/
    └── KeyboardNavigation.md           # Internal docs
```

---

## 6. User Experience Design

### 6.1 User Interface Principles

1. **Minimalism**: Clean, distraction-free interface focused on content
2. **Keyboard-First**: All functionality accessible via keyboard
3. **Clarity**: Clear visual hierarchy and status indicators
4. **Consistency**: Follows macOS Human Interface Guidelines
5. **Responsiveness**: Immediate feedback for all user actions
6. **Accessibility**: Fully accessible to all users

### 6.2 Visual Design System

#### Design Tokens
- **Spacing Scale**: 4px, 8px, 12px, 16px, 20px, 24px, 32px, 48px
- **Border Radius**: 4px (small), 8px (medium), 12px (large), 16px (extra-large)
- **Shadows**: Subtle elevation with 3 levels (small, medium, large)
- **Typography**: SF Pro (system font) with 6 predefined scales

#### Color System
- **Light Mode**: Clean whites and subtle grays
- **Dark Mode**: True black backgrounds with refined grays
- **Accent Color**: System tint color (customizable)
- **Semantic Colors**: Success (green), Warning (yellow), Error (red)

#### Animation Guidelines
- **Duration**: 150ms (micro), 250ms (standard), 400ms (expressive)
- **Easing**: Ease-in-out for most transitions
- **Reduced Motion**: Instant transitions when enabled
- **Performance**: 60fps target, GPU-accelerated

### 6.3 Key User Flows

#### First Launch Flow
```
1. App Launch
   ↓
2. Welcome Screen
   ↓
3. Folder Selection Dialog
   ↓
4. Permission Request (if needed)
   ↓
5. Folder Scanning (with progress)
   ↓
6. First Image Display
   ↓
7. AI Consent Dialog (macOS 26+ only, first run)
   ↓
8. What's New Sheet (if version update)
```

#### Image Viewing Flow
```
1. Image Display
   ↓
2. Navigate with Arrow Keys / Click Next
   ↓
3. Zoom with +/- / Pinch
   ↓
4. Toggle View Mode (T/G)
   ↓
5. Open AI Insights (I) [macOS 26+ only]
   ↓
6. View Image Info Overlay
```

#### AI Analysis Flow (macOS 26+)
```
1. Image Displayed
   ↓
2. Auto Analysis (if enabled)
   ↓
3. Progress Indicator
   ↓
4. Results Display in Panel
   ↓
5. Explore Tags, Objects, Scenes
   ↓
6. Copy/Share Insights
```

### 6.4 Interaction Patterns

#### Keyboard Shortcuts
| Category | Shortcuts |
|----------|-----------|
| **Navigation** | ←/→ (prev/next), Home/End (first/last), Space (next) |
| **Zoom** | +/- (zoom in/out), 0 (fit), 1 (actual size) |
| **View Modes** | T (thumbnails), G (grid), F/Enter (fullscreen), Esc (exit) |
| **Features** | S (slideshow), I (image info/AI insights), ⌘? (help) |
| **Window** | ⌘W (close), ⌘M (minimize), ⌘Q (quit) |

#### Mouse/Trackpad
- **Click Navigation**: Previous/Next buttons
- **Double-Click**: Toggle fullscreen (on image)
- **Pinch Zoom**: Two-finger zoom gesture
- **Swipe Navigation**: Two-finger swipe left/right
- **Scroll**: Pan zoomed image

### 6.5 Error Handling UX

#### Error Presentation
- **Inline Errors**: Show within context (e.g., folder picker)
- **Alert Dialogs**: For critical errors requiring attention
- **Toast Notifications**: For non-blocking informational errors
- **Retry Options**: Always provide recovery actions

#### Error Messages
- **User-Friendly**: Plain language, no technical jargon
- **Actionable**: Clear next steps
- **Contextual**: Relevant to the situation
- **Helpful**: Links to help resources when appropriate

---

## 7. AI Features Detailed Requirements

### 7.1 AI System Architecture (macOS 26+)

#### Core ML Model Pipeline
```
┌─────────────────────────────────────────────┐
│          AI Image Analysis Service           │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │     ResNet50 Core ML Model (Primary)  │ │
│  │     - Image Classification            │ │
│  │     - Subject Identification          │ │
│  │     - Confidence Scoring              │ │
│  └───────────────────────────────────────┘ │
│                    ↓                        │
│  ┌───────────────────────────────────────┐ │
│  │   Vision Framework (Fallback/Extend)  │ │
│  │     - VNClassifyImageRequest          │ │
│  │     - VNRecognizeAnimalsRequest       │ │
│  │     - VNDetectHumanRectanglesRequest  │ │
│  │     - VNRecognizeTextRequest (OCR)    │ │
│  └───────────────────────────────────────┘ │
│                    ↓                        │
│  ┌───────────────────────────────────────┐ │
│  │      Quality Assessment Module        │ │
│  │     - Blur detection (Laplacian)      │ │
│  │     - Exposure analysis (Histogram)   │ │
│  │     - Resolution assessment           │ │
│  └───────────────────────────────────────┘ │
│                    ↓                        │
│  ┌───────────────────────────────────────┐ │
│  │      Natural Language Generation      │ │
│  │     - Tag extraction                  │ │
│  │     - Description synthesis           │ │
│  │     - Insight generation              │ │
│  └───────────────────────────────────────┘ │
│                    ↓                        │
│  ┌───────────────────────────────────────┐ │
│  │         LRU Cache (20 entries)        │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### 7.2 AI Analysis Result Structure

```swift
struct ImageAnalysisResult {
    // Primary Classification (ResNet50 + Vision)
    let primarySubject: String
    let primaryConfidence: Float
    let alternativeClassifications: [(String, Float)]

    // Object Detection
    let detectedObjects: [DetectedObject]
    let humanCount: Int
    let animalCount: Int

    // Scene Understanding
    let sceneClassifications: [SceneClassification]
    let isIndoor: Bool
    let lightingCondition: LightingCondition

    // Text Recognition
    let recognizedText: [RecognizedText]
    let hasText: Bool

    // Color Analysis
    let dominantColors: [NSColor]
    let colorPalette: [String: Float]

    // Quality Metrics
    let qualityScore: Int // 0-100
    let sharpnessScore: Float
    let exposureAssessment: ExposureLevel
    let hasBlur: Bool
    let hasNoise: Bool

    // Generated Content
    let smartTags: [String]
    let description: String
    let insights: [String]
    let enhancementSuggestions: [String]

    // Metadata
    let analysisDate: Date
    let processingTime: TimeInterval
}
```

### 7.3 AI Performance Requirements

| Operation | Target Time | Maximum Time |
|-----------|-------------|--------------|
| **ResNet50 Classification** | 500ms | 1 second |
| **Vision Object Detection** | 300ms | 800ms |
| **Scene Classification** | 200ms | 500ms |
| **Text Recognition (OCR)** | 500ms | 1.5 seconds |
| **Quality Assessment** | 150ms | 300ms |
| **Tag Generation** | 100ms | 200ms |
| **Description Generation** | 200ms | 400ms |
| **Total Analysis** | 1-2 seconds | 5 seconds |

### 7.4 AI Privacy and Consent

#### User Consent Flow
1. **First Run**: Present AI features dialog on macOS 26+
2. **Clear Explanation**: Describe what AI does, privacy guarantees
3. **Opt-In Required**: User must explicitly enable
4. **Easy Disable**: Toggle in Preferences > General
5. **No Pressure**: Full functionality without AI

#### Privacy Guarantees
- **100% On-Device**: All processing using local Core ML and Vision
- **Zero Network**: No internet connection required or used
- **No Cloud Services**: No external API calls
- **No Data Collection**: Analysis results stored locally only
- **User Control**: Easy enable/disable anytime

### 7.5 AI Feature Discoverability

#### In-App Promotion
- **First Launch Banner** (macOS 26+): "Discover AI-powered insights"
- **Toolbar Icon**: Brain icon with badge for new feature
- **Contextual Tooltips**: "View AI analysis for this image"
- **What's New**: Highlight AI features in update notes

#### Educational Content
- **Help Documentation**: Dedicated AI features section
- **Interactive Tutorial**: Optional walkthrough
- **Example Results**: Sample images with AI insights
- **Privacy FAQ**: Address user concerns

---

## 8. Release and Deployment

### 8.1 Release Strategy

#### Version Numbering
- **Major.Minor.Patch** (Semantic Versioning)
- **Current**: 2.5.0
- **Major**: Breaking changes, major feature additions
- **Minor**: New features, non-breaking changes
- **Patch**: Bug fixes, minor improvements

#### Release Cadence
- **Major Releases**: Every 12-18 months
- **Minor Releases**: Every 2-4 months
- **Patch Releases**: As needed for critical bugs
- **Beta Program**: 2-4 weeks before public release

### 8.2 Mac App Store Submission

#### App Store Requirements
- **App Name**: StillView - Simple Image Viewer
- **Bundle ID**: com.vinny.StillView-Simple-Image-Viewer
- **Category**: Graphics & Design
- **Price**: Free (freemium model possible future)
- **Age Rating**: 4+

#### Submission Checklist
- [ ] Valid Apple Developer certificate
- [ ] App Sandbox enabled
- [ ] Privacy manifest included
- [ ] Entitlements minimal and justified
- [ ] No private API usage
- [ ] Screenshot set (5 required)
- [ ] App preview video (optional)
- [ ] Localized metadata
- [ ] TestFlight beta testing complete
- [ ] No crashes in production build
- [ ] Memory usage within limits

### 8.3 Distribution Channels

#### Primary: Mac App Store
- **Advantages**: Automatic updates, user trust, discoverability
- **Requirements**: Strict review, sandbox compliance
- **Update Mechanism**: Apple-managed automatic updates

#### Secondary: Direct Distribution (Optional Future)
- **Advantages**: Faster updates, more control
- **Requirements**: Notarization, code signing
- **Update Mechanism**: Sparkle framework or custom

### 8.4 Build Configurations

#### Debug Build
- **Optimization**: None (-Onone)
- **Symbols**: Full debug symbols included
- **Logging**: Verbose logging enabled
- **Assertions**: All assertions enabled
- **Provisioning**: Development profile

#### Release Build
- **Optimization**: Full (-O)
- **Symbols**: Stripped for App Store
- **Logging**: Critical errors only
- **Assertions**: Disabled
- **Provisioning**: Distribution profile
- **LTO**: Link-Time Optimization enabled
- **Bitcode**: Not required for macOS

### 8.5 Continuous Integration/Deployment

#### CI Pipeline (Recommended)
1. **Code Commit** → Trigger build
2. **Unit Tests** → Run test suite
3. **UI Tests** → Automated interaction tests
4. **Static Analysis** → SwiftLint, code quality
5. **Build Archive** → Create .xcarchive
6. **Notarization** → Apple notarization service
7. **Upload** → TestFlight / App Store Connect

#### Automated Testing
- **Unit Tests**: Run on every commit
- **Integration Tests**: Run on PR merge
- **UI Tests**: Run nightly
- **Performance Tests**: Run weekly
- **Memory Leak Detection**: Instruments automation

---

## 9. Success Metrics and KPIs

### 9.1 User Acquisition Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **App Store Downloads** | 10,000 in first 3 months | App Store Connect |
| **Monthly Active Users (MAU)** | 5,000 after 6 months | Analytics (privacy-preserving) |
| **Daily Active Users (DAU)** | 1,000 after 6 months | Analytics |
| **DAU/MAU Ratio** | >20% (sticky product) | Calculated |
| **User Retention (7-day)** | >40% | Cohort analysis |
| **User Retention (30-day)** | >25% | Cohort analysis |

### 9.2 Engagement Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Average Session Duration** | >5 minutes | Analytics |
| **Images Viewed per Session** | >20 images | Analytics |
| **Keyboard Shortcut Usage** | >70% of power users | Feature usage tracking |
| **Grid View Adoption** | >40% users try within first week | Feature flags |
| **Slideshow Usage** | >30% users try within first month | Feature usage |
| **AI Feature Adoption** | >60% of macOS 26+ users enable | Preference tracking |

### 9.3 Performance Metrics

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| **App Crash Rate** | <0.1% sessions | <1% sessions |
| **Average Load Time** | <500ms per image | <1 second |
| **Memory Usage (p95)** | <500MB | <1GB |
| **CPU Usage (avg)** | <20% | <50% |
| **Battery Impact** | Low (per macOS energy metrics) | Medium maximum |

### 9.4 Quality Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **App Store Rating** | >4.5 stars | App Store Connect |
| **Bug Reports per Release** | <10 critical bugs | Issue tracker |
| **Test Coverage** | >70% code coverage | Xcode coverage reports |
| **Accessibility Compliance** | 100% WCAG 2.1 AA | Accessibility audit |
| **Time to Fix Critical Bugs** | <48 hours | Issue resolution time |

### 9.5 AI Feature Metrics (macOS 26+)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **AI Consent Rate** | >60% opt-in | Preference tracking |
| **AI Analysis Success Rate** | >95% successful | Error logging |
| **Average Analysis Time** | <2 seconds | Performance logging |
| **AI Insights Panel Opens** | >3 per session (AI users) | Feature usage |
| **Tag Utility Rating** | >4/5 stars (user feedback) | In-app survey |

---

## 10. Risks and Mitigation

### 10.1 Technical Risks

#### Risk: Memory Management Issues
- **Probability**: Medium
- **Impact**: High (crashes, poor UX)
- **Mitigation**:
  - Comprehensive memory pressure monitoring
  - Extensive testing with large image collections (10,000+ images)
  - Intelligent cache eviction strategies
  - Automated memory leak detection in CI

#### Risk: AI Model Performance Degradation
- **Probability**: Low
- **Impact**: Medium (slower analysis, reduced accuracy)
- **Mitigation**:
  - Multiple fallback models (ResNet50 → Vision framework)
  - Performance benchmarking suite
  - User-configurable analysis depth
  - Graceful degradation to basic features

#### Risk: Sandbox Permission Complications
- **Probability**: Medium
- **Impact**: High (loss of folder access)
- **Mitigation**:
  - Robust security-scoped bookmark handling
  - Bookmark staleness detection and recovery
  - Clear user communication about permissions
  - Fallback to re-request access

### 10.2 User Experience Risks

#### Risk: Complex UI Overwhelming Users
- **Probability**: Low
- **Impact**: Medium (reduced adoption)
- **Mitigation**:
  - Progressive disclosure of advanced features
  - Comprehensive onboarding and help system
  - Default to simple, clean interface
  - User testing with diverse user groups

#### Risk: Keyboard-First Design Excludes Users
- **Probability**: Low
- **Impact**: Medium (accessibility concerns)
- **Mitigation**:
  - Full mouse/trackpad support in parallel
  - Clear visual keyboard shortcut indicators
  - Tooltips on all interactive elements
  - Comprehensive help documentation

### 10.3 Market Risks

#### Risk: Low Differentiation from Competitors
- **Probability**: Medium
- **Impact**: High (low adoption)
- **Mitigation**:
  - Unique AI-powered features (macOS 26+)
  - Best-in-class keyboard navigation
  - Privacy-first positioning
  - Native macOS integration and performance

#### Risk: Limited macOS 26 Adoption
- **Probability**: High (early macOS version)
- **Impact**: Medium (reduced AI feature usage)
- **Mitigation**:
  - Full functionality on macOS 12+
  - AI features as premium addition, not core requirement
  - Clear communication about AI availability
  - Graceful feature degradation

### 10.4 Privacy and Security Risks

#### Risk: App Store Rejection due to Privacy Concerns
- **Probability**: Low
- **Impact**: High (delayed release)
- **Mitigation**:
  - Privacy manifest with clear declarations
  - No network access, no data collection
  - Transparent AI processing (on-device only)
  - Pre-submission privacy review

#### Risk: Security-Scoped Bookmark Failures
- **Probability**: Medium
- **Impact**: Medium (user frustration)
- **Mitigation**:
  - Bookmark validation on app launch
  - Graceful re-request of access
  - Clear error messages and recovery steps
  - Extensive testing of edge cases

---

## 11. Future Roadmap

### 11.1 Version 3.0 (6-12 Months)

#### Major Features
- **Smart Collections**: AI-powered automatic image organization
- **Advanced Search**: Natural language search using AI tags
- **Batch Operations**: Multi-image actions (copy, move, export)
- **Cloud Sync**: iCloud sync for favorites and preferences (optional)
- **Video Support**: Basic video playback (MP4, MOV)

#### AI Enhancements
- **Similarity Search**: Find visually similar images
- **Duplicate Detection**: Intelligent duplicate identification
- **Face Recognition**: Organize by detected people
- **Smart Cropping**: AI-suggested crop recommendations

### 11.2 Version 3.5 (12-18 Months)

#### Major Features
- **Annotation Tools**: Basic markup and drawing
- **Compare Mode**: Side-by-side image comparison
- **Advanced Filters**: Core Image-based filter presets
- **Share Extensions**: Native macOS share sheet integration
- **Printing**: High-quality print layout and output

#### AI Enhancements
- **Style Transfer**: AI-powered artistic filters
- **Upscaling**: AI-based image enhancement and upscaling
- **Object Removal**: Intelligent content-aware fill
- **Background Replacement**: AI-powered background editing

### 11.3 Version 4.0 (18-24 Months)

#### Major Features
- **RAW Support**: Full RAW image format support
- **Color Management**: ICC profile support, color spaces
- **Plugin System**: Third-party plugin architecture
- **Automation**: AppleScript and Shortcuts support
- **Multi-Window**: Multiple viewer windows

#### Platform Expansion
- **iOS Companion**: iPhone/iPad companion app
- **Handoff Support**: Seamless continuity across devices
- **Universal Purchase**: Single purchase across all platforms

### 11.4 Continuous Improvements

#### Ongoing Priorities
- **Performance Optimization**: Faster loading, lower memory usage
- **Accessibility Enhancements**: Expanded VoiceOver support
- **Localization**: Additional languages (Spanish, French, German, Japanese, Chinese)
- **Bug Fixes**: Regular quality improvements
- **macOS Updates**: Support for latest macOS features

---

## 12. Appendix

### 12.1 Glossary

| Term | Definition |
|------|------------|
| **App Sandbox** | macOS security technology that limits app access to system resources |
| **Core ML** | Apple's machine learning framework for on-device inference |
| **ImageIO** | macOS framework for reading and writing image data |
| **LRU Cache** | Least Recently Used cache eviction strategy |
| **MVVM** | Model-View-ViewModel architectural pattern |
| **ResNet50** | 50-layer Residual Neural Network for image classification |
| **Security-Scoped Bookmark** | Persistent file access token for sandboxed apps |
| **SwiftUI** | Apple's declarative UI framework |
| **UTType** | Uniform Type Identifier for file types |
| **Vision Framework** | Apple's computer vision framework |
| **VoiceOver** | macOS screen reader for accessibility |

### 12.2 References

#### Apple Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Core ML Documentation](https://developer.apple.com/documentation/coreml/)
- [Vision Framework Guide](https://developer.apple.com/documentation/vision/)
- [App Sandbox Design Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos/)

#### External Resources
- [ResNet50 Model Architecture](https://arxiv.org/abs/1512.03385)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

### 12.3 Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-07 | Product Team | Initial PRD creation based on codebase analysis |

### 12.4 Stakeholders

| Role | Name | Responsibilities |
|------|------|-----------------|
| **Product Owner** | Vinny Carpenter | Overall product direction, feature prioritization |
| **Lead Developer** | Vinny Carpenter | Technical architecture, implementation |
| **UX Designer** | TBD | User experience, interface design |
| **QA Lead** | TBD | Quality assurance, testing strategy |
| **Marketing** | TBD | Go-to-market strategy, user acquisition |

---

## Document Approval

**Status**: Draft for Review
**Next Review Date**: Q1 2026
**Approved By**: Pending

---

*This Product Requirements Document is a living document and will be updated as the product evolves based on user feedback, technical constraints, and market conditions.*

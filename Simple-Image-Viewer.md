# Simple Image Viewer Application - Technical Specification

**Document Version:** 1.0
**Date:** July 25, 2025
**Author:** Vinny Carpenter

---

## 1. Overview

### 1.1 Purpose
This specification defines the requirements for a simple, elegant macOS image viewer application designed for publication on the Apple Mac App Store. The application prioritizes ease of use, visual minimalism, and efficient folder-based image browsing.

### 1.2 High-Level Description
The application will allow users to select a folder containing images and browse through them using intuitive keyboard navigation. The interface will be clean and distraction-free, focusing the user's attention on the images themselves while providing essential navigation controls.

### 1.3 Target Audience
- Casual users who need a simple image viewer
- Photographers organizing and reviewing image collections
- Users seeking a lightweight alternative to complex image editing software

---

## 2. Supported Platforms & Store Compliance

### 2.1 Platform Requirements
- **Minimum macOS Version:** macOS 12.0 (Monterey)
- **Recommended Target:** macOS 13.0+ (Ventura and later)
- **Architecture Support:** Universal Binary (Intel x86_64 and Apple Silicon arm64)

### 2.2 App Store Compliance
- Full compliance with Apple Mac App Store Review Guidelines
- App Sandbox enabled (required for Mac App Store)
- Code signing with valid Developer ID
- Notarization requirements met
- Privacy manifest included
- No use of deprecated APIs

---

## 3. Core Features

### 3.1 Supported Image Formats
**Primary Formats (Required):**
- JPEG/JPG
- PNG
- GIF (including animated GIFs)
- HEIF/HEIC (High Efficiency Image Format)
- WebP

**Extended Formats (Nice-to-Have):**
- TIFF
- BMP
- PDF (first page preview)
- SVG (basic support)

### 3.2 Folder Navigation
- Folder selection via standard macOS file picker
- Automatic scanning of selected folder for supported image files
- Recursive subdirectory scanning (optional toggle in preferences)
- Real-time folder monitoring for added/removed images
- Support for folders containing mixed file types (non-images ignored)

### 3.3 Image Display
- Automatic image scaling to fit window while maintaining aspect ratio
- Zoom controls (fit to window, actual size, custom zoom levels)
- High-quality image rendering using Core Graphics
- Smooth transitions between images
- Loading indicators for large images

### 3.4 Keyboard Navigation
**Primary Navigation:**
- **Right Arrow / Spacebar:** Next image
- **Left Arrow:** Previous image
- **Home:** First image in folder
- **End:** Last image in folder

**Additional Controls:**
- **Escape:** Exit fullscreen or close application
- **F / Enter:** Toggle fullscreen mode
- **+/= :** Zoom in
- **-:** Zoom out
- **0:** Reset zoom to fit window
- **1:** Zoom to actual size (100%)

### 3.5 User Interface Elements
- **Minimal toolbar** with essential controls
- **Image counter** (e.g., "5 of 23")
- **File name display** (optional, toggleable)
- **Zoom level indicator**
- **Loading progress indicator**
- Clean, distraction-free design following macOS Human Interface Guidelines

---

## 4. User Flow

### 4.1 Initial Launch Flow
1. User launches application
2. Application presents folder selection dialog
3. User selects folder containing images
4. Application scans folder and displays first image
5. User can navigate through images using keyboard shortcuts

### 4.2 Typical Usage Flow
1. **Folder Selection:**
   - Click "Open Folder" button or use Cmd+O
   - Navigate to desired folder in file picker
   - Confirm selection

2. **Image Browsing:**
   - First image displays automatically
   - Use arrow keys or spacebar to navigate
   - Image counter shows current position
   - Smooth transitions between images

3. **Viewing Options:**
   - Toggle fullscreen with F key
   - Adjust zoom level as needed
   - View image metadata (optional)

4. **Folder Management:**
   - Switch to different folder anytime
   - Application remembers recent folders
   - Option to open new folder without closing current session

### 4.3 Error Handling Flow
1. **No Images Found:** Display friendly message with suggestion to select different folder
2. **Corrupted Images:** Skip corrupted files, show brief notification
3. **Permission Issues:** Request appropriate permissions with clear explanation
4. **Large Images:** Show loading indicator, allow cancellation if needed

---

## 5. Technical Requirements

### 5.1 Development Framework
- **Primary Language:** Swift 5.9+
- **UI Framework:** SwiftUI with AppKit integration where necessary
- **Minimum Xcode Version:** Xcode 15.0

### 5.2 Core APIs and Frameworks
- **ImageIO Framework:** For image loading and metadata
- **Core Graphics:** For image rendering and transformations
- **AppKit:** For file system integration and window management
- **UniformTypeIdentifiers:** For file type detection
- **Combine:** For reactive programming patterns

### 5.3 Architecture Pattern
- **MVVM (Model-View-ViewModel)** architecture
- **Coordinator pattern** for navigation flow
- **Repository pattern** for file system operations
- Clear separation of concerns between UI and business logic

### 5.4 Performance Requirements
- **Image Loading:** Lazy loading with background processing
- **Memory Management:** Intelligent caching with memory pressure handling
- **Responsiveness:** UI must remain responsive during image loading
- **Startup Time:** Application launch under 2 seconds on supported hardware
- **Navigation Speed:** Less than 100ms transition time between images

### 5.5 Data Management
- **No persistent data storage** (images remain in original locations)
- **Preferences storage** using UserDefaults
- **Recent folders list** (maximum 10 entries)
- **Window state persistence** (size, position)

---

## 6. Non-Functional Requirements

### 6.1 Security & Sandboxing
- **App Sandbox enabled** with minimal required entitlements
- **File system access** limited to user-selected folders
- **Network access:** None required (purely local application)
- **Required Entitlements:**
  - `com.apple.security.files.user-selected.read-only`
  - `com.apple.security.files.bookmarks.app-scope`

### 6.2 Accessibility
- **VoiceOver support** for all UI elements
- **Keyboard navigation** for all functionality
- **High contrast mode** compatibility
- **Reduced motion** preference support
- **Image descriptions** where metadata available

### 6.3 Localization
- **Base Language:** English
- **String externalization** for future localization
- **RTL language support** consideration in UI design
- **Number and date formatting** following system preferences

### 6.4 Error Handling & Logging
- **Graceful error handling** with user-friendly messages
- **Crash reporting** (if permitted by App Store guidelines)
- **Debug logging** for development builds only
- **No telemetry or analytics** to ensure privacy compliance

---

## 7. App Store Readiness

### 7.1 Code Signing & Distribution
- **Valid Apple Developer Program membership** required
- **Developer ID Application certificate** for code signing
- **Notarization** through Apple's notary service
- **Universal Binary** supporting both Intel and Apple Silicon

### 7.2 Required Entitlements
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

### 7.3 App Store Metadata
- **App Name:** TBD (must be unique in App Store)
- **Category:** Graphics & Design or Productivity
- **Age Rating:** 4+ (no restricted content)
- **Keywords:** image viewer, photo browser, picture viewer
- **Privacy Policy:** Required (even if minimal data collection)

### 7.4 Review Guidelines Compliance
- **Guideline 4.2.1:** Minimum functionality requirements met
- **Guideline 2.1:** App completeness before submission
- **Guideline 5.1.1:** Privacy policy and data collection transparency
- **Guideline 2.4.5:** No use of deprecated or private APIs

### 7.5 Testing Requirements
- **Comprehensive testing** on multiple macOS versions
- **Performance testing** with large image collections
- **Accessibility testing** with VoiceOver enabled
- **Sandbox testing** to ensure proper entitlement configuration

---

## 8. Future Enhancements

### 8.1 Phase 2 Features (Post-Launch)
- **Basic image editing:** Rotate, flip, crop
- **Slideshow mode** with configurable timing
- **Image comparison** (side-by-side view)
- **Metadata panel** showing EXIF data
- **Search functionality** within current folder

### 8.2 Advanced Features (Long-term)
- **Multiple folder support** with tabs
- **Image ratings and tagging** (non-destructive)
- **Export options** (resize, format conversion)
- **Integration with Photos app**
- **Cloud storage support** (iCloud Drive, etc.)

### 8.3 Performance Optimizations
- **Thumbnail generation** for faster browsing
- **Predictive loading** of adjacent images
- **GPU acceleration** for image processing
- **Background processing** for folder scanning

---

## 9. Constraints and Assumptions

### 9.1 Technical Constraints
- Must work within App Sandbox limitations
- No network access required or permitted
- Limited to read-only file system access
- Must support both Intel and Apple Silicon Macs

### 9.2 Business Constraints
- Free application (no in-app purchases initially)
- Must pass App Store review process
- Development timeline: 8-12 weeks
- Single developer or small team implementation

### 9.3 Assumptions
- Users have basic familiarity with macOS applications
- Image files are stored locally on the Mac
- Users prefer keyboard navigation over mouse interaction
- Simplicity is valued over feature completeness

---

## 10. Success Criteria

### 10.1 Functional Success
- Application successfully loads and displays all supported image formats
- Keyboard navigation works smoothly without lag
- Folder selection and scanning completes without errors
- Application passes all App Store review requirements

### 10.2 User Experience Success
- Users can browse images intuitively without documentation
- Application feels fast and responsive during normal usage
- Interface remains clean and distraction-free
- No crashes or data loss during typical usage scenarios

### 10.3 Technical Success
- Application launches consistently under 2 seconds
- Memory usage remains reasonable with large image collections
- Code coverage above 80% for critical functionality
- Successful App Store approval on first submission

---

*This specification serves as the foundation for development and should be reviewed and updated as requirements evolve during the development process.*

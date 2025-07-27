# StillView - Simple Image Viewer

> **"Because sometimes, simple is perfect."**

[![macOS](https://img.shields.io/badge/macOS-12.0+-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange)](https://swift.org/)
[![App Store](https://img.shields.io/badge/Available_on-Mac_App_Store-blue?logo=apple)](https://apps.apple.com/app/simple-image-viewer/)

A minimalist, elegant image viewer designed specifically for macOS users who want a clean, distraction-free way to browse through image collections. Built with SwiftUI and optimized for the Mac App Store.

## ✨ Features

### 🖼️ **Effortless Browsing**
Browse through entire folders of images with intuitive keyboard shortcuts. No complex menus or overwhelming interfaces—just pure image viewing.

### ⌨️ **Keyboard-First Design**
- **Arrow keys** for navigation
- **+/-** for zoom control
- **F** or **Enter** for fullscreen
- **Space** for next image
- **Home/End** for first/last image

### 🎨 **Universal Format Support**
View all your images with crystal-clear quality:
- **Primary**: JPEG, PNG, GIF (animated), HEIF/HEIC, WebP
- **Extended**: TIFF, BMP, SVG, PDF

### ✨ **macOS Native Experience**
- Full **VoiceOver** and accessibility support
- **High contrast mode** compatibility
- **Reduced motion** preferences respected
- Native macOS design language
- Universal Binary (Intel + Apple Silicon)

### 🔒 **Privacy First**
- **No internet required** - works completely offline
- **No data collection** or tracking
- **App Sandbox** enabled for maximum security
- Only accesses folders you explicitly select

## 🚀 Getting Started

### System Requirements
- macOS 12.0 (Monterey) or later
- Compatible with Intel and Apple Silicon Macs

### Installation
Download from the [Mac App Store](https://apps.apple.com/app/simple-image-viewer/) or build from source.

### Building from Source
1. Clone this repository
2. Open `Simple Image Viewer.xcodeproj` in Xcode
3. Build and run (⌘+R)

## 🏗️ Architecture

Simple Image Viewer follows a clean **MVVM architecture** with protocol-oriented design:

```
Simple Image Viewer/
├── App/                    # App coordination and entry point
├── Models/                 # Core data models and business logic
├── ViewModels/            # MVVM view models with Combine
├── Views/                 # SwiftUI views and components
├── Services/              # Business services and protocols
└── Extensions/            # Utility extensions
```

### Key Components
- **ImageViewerViewModel**: Main state management for image viewing
- **FileSystemService**: Security-scoped folder access and scanning
- **ImageLoaderService**: Async image loading with memory management
- **KeyboardHandler**: Global keyboard shortcuts and navigation

## 🧪 Testing

Run the comprehensive test suite:
```bash
# In Xcode: ⌘+U or use Test Navigator
```

Tests include:
- Unit tests for all models and services
- Integration tests for file system operations
- UI component testing

## 🎯 Perfect For

- **Photographers** reviewing image collections
- **Designers** browsing asset folders
- **Anyone** seeking a lightweight, efficient image viewer
- Users who prefer **keyboard navigation**
- Those who value **privacy** and **simplicity**

## 🔧 Development

### Project Structure
- **Target**: macOS 12.0+, optimized for macOS 14.6+
- **Language**: Swift 5.0+ with SwiftUI
- **Frameworks**: SwiftUI, Combine, AppKit, ImageIO
- **Bundle ID**: `com.vinny.Simple-Image-Viewer`

### Key Development Notes
- Uses **security-scoped bookmarks** for persistent folder access
- Implements **memory pressure handling** for large image collections
- **Real-time folder monitoring** detects file system changes
- **Comprehensive accessibility** support throughout

## 📝 License

This project is open source. See [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📞 Support

- Create an [issue](https://github.com/vscarpenter/SimpleImageViewer/issues) for bug reports
- Star ⭐ this repository if you find it useful

---

**Simple Image Viewer** - Elegant folder-based image browsing for macOS
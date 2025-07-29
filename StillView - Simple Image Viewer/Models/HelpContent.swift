//
//  HelpContent.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import Foundation

/// Help content structure for the application
struct HelpContent {
    let sections: [HelpSection]
    
    static let shared = HelpContent(sections: [
        .gettingStarted,
        .keyboardShortcuts,
        .navigation,
        .thumbnailViewing,
        .zoomAndView,
        .additionalFeatures,
        .supportedFormats,
        .troubleshooting,
        .about
    ])
}

// MARK: - Help Section Model
struct HelpSection {
    let title: String
    let icon: String
    let items: [HelpItem]
}

struct HelpItem {
    let title: String
    let description: String
    let shortcut: String?
    let type: HelpItemType
    
    init(title: String, description: String, shortcut: String? = nil, type: HelpItemType = .information) {
        self.title = title
        self.description = description
        self.shortcut = shortcut
        self.type = type
    }
}

enum HelpItemType {
    case information
    case shortcut
    case tip
    case warning
    
    var iconName: String {
        switch self {
        case .information:
            return "info.circle"
        case .shortcut:
            return "keyboard"
        case .tip:
            return "lightbulb"
        case .warning:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Help Sections
extension HelpSection {
    static let gettingStarted = HelpSection(
        title: "Getting Started",
        icon: "play.circle",
        items: [
            HelpItem(
                title: "Opening Images",
                description: "Use 'Open Folder...' from the File menu or press ⌘O to select a folder containing images. StillView will automatically scan the folder and display all supported image files.",
                shortcut: "⌘O",
                type: .information
            ),
            HelpItem(
                title: "Basic Navigation",
                description: "Once images are loaded, use the arrow keys or click the navigation controls to browse through your images. The current image position is shown in the bottom status bar.",
                type: .information
            ),
            HelpItem(
                title: "Quick Start Tip",
                description: "For the best experience, organize your images in folders and use StillView's keyboard shortcuts for fast, distraction-free browsing. Try the thumbnail views ('T' and 'G') for quick navigation through large collections.",
                type: .tip
            )
        ]
    )
    
    static let keyboardShortcuts = HelpSection(
        title: "Keyboard Shortcuts",
        icon: "keyboard",
        items: [
            HelpItem(
                title: "Open Folder",
                description: "Open a folder selection dialog",
                shortcut: "⌘O",
                type: .shortcut
            ),
            HelpItem(
                title: "Next Image",
                description: "Navigate to the next image in the folder",
                shortcut: "→ or Space",
                type: .shortcut
            ),
            HelpItem(
                title: "Previous Image",
                description: "Navigate to the previous image in the folder",
                shortcut: "←",
                type: .shortcut
            ),
            HelpItem(
                title: "First Image",
                description: "Jump to the first image in the folder",
                shortcut: "Home",
                type: .shortcut
            ),
            HelpItem(
                title: "Last Image",
                description: "Jump to the last image in the folder",
                shortcut: "End",
                type: .shortcut
            ),
            HelpItem(
                title: "Zoom In",
                description: "Increase image magnification",
                shortcut: "+ or =",
                type: .shortcut
            ),
            HelpItem(
                title: "Zoom Out",
                description: "Decrease image magnification",
                shortcut: "-",
                type: .shortcut
            ),
            HelpItem(
                title: "Fit to Window",
                description: "Scale image to fit within the window",
                shortcut: "0",
                type: .shortcut
            ),
            HelpItem(
                title: "Actual Size",
                description: "Display image at 100% scale (actual pixels)",
                shortcut: "1",
                type: .shortcut
            ),
            HelpItem(
                title: "Toggle Fullscreen",
                description: "Enter or exit fullscreen viewing mode",
                shortcut: "F or Enter",
                type: .shortcut
            ),
            HelpItem(
                title: "Exit Fullscreen",
                description: "Exit fullscreen mode",
                shortcut: "Escape",
                type: .shortcut
            ),
            HelpItem(
                title: "Show Image Info",
                description: "Toggle image metadata and EXIF information overlay",
                shortcut: "I",
                type: .shortcut
            ),
            HelpItem(
                title: "Toggle Slideshow",
                description: "Start or stop automatic slideshow mode",
                shortcut: "S",
                type: .shortcut
            ),
            HelpItem(
                title: "Thumbnail Strip",
                description: "Show/hide horizontal thumbnail strip at bottom",
                shortcut: "T",
                type: .shortcut
            ),
            HelpItem(
                title: "Grid View",
                description: "Open full-screen thumbnail grid for quick navigation",
                shortcut: "G",
                type: .shortcut
            ),
            HelpItem(
                title: "Back to Folder Selection",
                description: "Return to folder selection screen",
                shortcut: "Escape or B",
                type: .shortcut
            ),
            HelpItem(
                title: "Help",
                description: "Show this help window",
                shortcut: "⌘?",
                type: .shortcut
            )
        ]
    )
    
    static let navigation = HelpSection(
        title: "Navigation & Controls",
        icon: "arrow.left.arrow.right",
        items: [
            HelpItem(
                title: "Browse Images",
                description: "Use arrow keys, spacebar, or navigation buttons to move between images. StillView automatically loads adjacent images for smooth browsing.",
                type: .information
            ),
            HelpItem(
                title: "Image Counter",
                description: "The bottom status bar shows your current position (e.g., '5 of 23') and the current image filename when enabled.",
                type: .information
            ),
            HelpItem(
                title: "Quick Navigation",
                description: "Use Home and End keys to quickly jump to the first or last image in the folder. Perfect for large image collections.",
                type: .tip
            ),
            HelpItem(
                title: "Folder Monitoring",
                description: "StillView automatically detects when images are added or removed from the current folder and updates the view accordingly.",
                type: .information
            )
        ]
    )
    
    static let thumbnailViewing = HelpSection(
        title: "Thumbnail Navigation",
        icon: "rectangle.grid.3x3",
        items: [
            HelpItem(
                title: "Thumbnail Strip",
                description: "Press 'T' or click the strip button to show a horizontal thumbnail strip at the bottom. Perfect for quick previews while maintaining focus on the main image.",
                shortcut: "T",
                type: .information
            ),
            HelpItem(
                title: "Grid View",
                description: "Press 'G' or click the grid button to open a full-screen thumbnail grid. Great for browsing large collections and jumping to specific images.",
                shortcut: "G",
                type: .information
            ),
            HelpItem(
                title: "Navigate with Thumbnails",
                description: "Click any thumbnail to instantly jump to that image. The current image is highlighted with a blue border and scroll position updates automatically.",
                type: .information
            ),
            HelpItem(
                title: "Thumbnail Performance",
                description: "Thumbnails are generated in the background and cached for smooth scrolling. The cache manages memory automatically to prevent system slowdowns.",
                type: .tip
            ),
            HelpItem(
                title: "Grid View Controls",
                description: "In grid view, use Escape to return to normal view, or click the 'Close' button. The grid shows image numbers, filenames, and file sizes for easy identification.",
                type: .information
            ),
            HelpItem(
                title: "Memory Efficient",
                description: "Thumbnail cache is limited to 25MB and 100 items to ensure smooth performance even with large image collections. Old thumbnails are automatically removed as needed.",
                type: .tip
            )
        ]
    )
    
    static let zoomAndView = HelpSection(
        title: "Zoom & View Controls",
        icon: "magnifyingglass",
        items: [
            HelpItem(
                title: "Zoom Modes",
                description: "StillView offers multiple zoom modes: Fit to Window (default), Actual Size (100%), and custom zoom levels from 10% to 500%.",
                type: .information
            ),
            HelpItem(
                title: "Pan Large Images",
                description: "When zoomed in beyond window size, click and drag to pan around large images. Use trackpad gestures for natural navigation.",
                type: .information
            ),
            HelpItem(
                title: "Fullscreen Mode",
                description: "Press F or Enter for distraction-free fullscreen viewing. Press Escape to exit. Perfect for presentations or detailed image review.",
                type: .information
            ),
            HelpItem(
                title: "Automatic Fitting",
                description: "When loading new images, StillView automatically fits them to the window size for optimal viewing. You can then zoom as needed.",
                type: .tip
            ),
            HelpItem(
                title: "High DPI Support",
                description: "StillView automatically handles Retina displays and high-DPI images, ensuring crisp rendering at all zoom levels.",
                type: .information
            )
        ]
    )
    
    static let additionalFeatures = HelpSection(
        title: "Additional Features",
        icon: "star",
        items: [
            HelpItem(
                title: "Image Information",
                description: "Press 'I' or click the info button to display image metadata including dimensions, file size, format, creation date, and camera EXIF data when available.",
                shortcut: "I",
                type: .information
            ),
            HelpItem(
                title: "Slideshow Mode",
                description: "Press 'S' or click the play button to start an automatic slideshow. Images advance every 3 seconds by default. Press 'S' again or spacebar to pause/resume.",
                shortcut: "S",
                type: .information
            ),
            HelpItem(
                title: "Slideshow Controls",
                description: "During slideshow mode, spacebar pauses/resumes, and arrow keys allow manual navigation. The slideshow automatically loops back to the first image when reaching the end.",
                type: .information
            ),
            HelpItem(
                title: "Status Bar Controls",
                description: "The bottom status bar contains toggle buttons for image info, slideshow, thumbnail views, and filename display. Hover over buttons for keyboard shortcut hints.",
                type: .information
            ),
            HelpItem(
                title: "EXIF Data Support",
                description: "View detailed camera information including aperture, shutter speed, ISO, focal length, and GPS coordinates when available in the image metadata.",
                type: .tip
            ),
            HelpItem(
                title: "Share Images",
                description: "Use the share button in the top toolbar to quickly share the current image via email, Messages, AirDrop, or other installed sharing services.",
                type: .information
            )
        ]
    )
    
    static let supportedFormats = HelpSection(
        title: "Supported Formats",
        icon: "photo",
        items: [
            HelpItem(
                title: "Primary Formats",
                description: "JPEG, PNG, GIF (including animated), HEIF/HEIC (iPhone photos), WebP",
                type: .information
            ),
            HelpItem(
                title: "Extended Formats",
                description: "TIFF, BMP, SVG, PDF (first page only)",
                type: .information
            ),
            HelpItem(
                title: "Modern iPhone Photos",
                description: "Full support for HEIF/HEIC format used by modern iPhones, including metadata and color profiles.",
                type: .information
            ),
            HelpItem(
                title: "Large Image Support",
                description: "StillView can handle very large images (100MB+) with intelligent memory management to prevent system slowdowns.",
                type: .information
            ),
            HelpItem(
                title: "Metadata Preservation",
                description: "Image metadata, EXIF data, and color profiles are preserved and respected for accurate color reproduction.",
                type: .tip
            )
        ]
    )
    
    static let troubleshooting = HelpSection(
        title: "Troubleshooting",
        icon: "wrench.and.screwdriver",
        items: [
            HelpItem(
                title: "Image Won't Load",
                description: "Ensure the file isn't corrupted and is in a supported format. StillView will automatically skip corrupted files and show the next valid image.",
                type: .warning
            ),
            HelpItem(
                title: "Memory Warnings",
                description: "If you see memory warnings, try closing other applications or restart StillView. Very large images (>100MB) may require more available system memory.",
                type: .warning
            ),
            HelpItem(
                title: "Folder Access Issues",
                description: "StillView uses security-scoped bookmarks to remember folder access. If you can't access a previously selected folder, try selecting it again.",
                type: .information
            ),
            HelpItem(
                title: "Performance Tips",
                description: "For best performance with large image collections, ensure your Mac has sufficient RAM and consider organizing images into smaller folders (100-500 images per folder). Thumbnail views work best with collections under 1000 images.",
                type: .tip
            ),
            HelpItem(
                title: "Thumbnail Loading",
                description: "Thumbnails generate automatically in the background. Large images may take a moment to appear in thumbnail views. The thumbnail cache persists between sessions for faster subsequent loading.",
                type: .information
            ),
            HelpItem(
                title: "App Sandbox Security",
                description: "StillView runs in a secure sandbox and only accesses folders you explicitly select. No data is collected or transmitted.",
                type: .information
            )
        ]
    )
    
    static let about = HelpSection(
        title: "About StillView",
        icon: "info.circle",
        items: [
            HelpItem(
                title: "Privacy First",
                description: "StillView works completely offline and never collects or transmits any data. Your images and viewing habits remain completely private.",
                type: .information
            ),
            HelpItem(
                title: "Universal Binary",
                description: "Optimized for both Intel and Apple Silicon Macs, ensuring excellent performance on all modern Mac computers.",
                type: .information
            ),
            HelpItem(
                title: "Accessibility",
                description: "Full VoiceOver support, keyboard navigation, and compatibility with macOS accessibility features.",
                type: .information
            ),
            HelpItem(
                title: "Open Source",
                description: "StillView is open source software. Visit the GitHub repository for source code, issues, and contributions.",
                type: .information
            ),
            HelpItem(
                title: "Support",
                description: "For support, bug reports, or feature requests, visit the GitHub Issues page or contact the developer through the repository.",
                type: .information
            )
        ]
    )
}
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

// swiftlint:disable file_length line_length
import Foundation

/// Help content structure for the application
struct HelpContent {
    let sections: [HelpSection]
    
    static let shared = HelpContent(sections: [
        .gettingStarted,
        .keyboardShortcuts,
        .consolidatedToolbar,
        .navigation,
        .thumbnailViewing,
        .zoomAndView,
        .aiFeatures,
        .preferences,
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
    let items: [HelpContentItem]
}

struct HelpContentItem {
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
            HelpContentItem(
                title: "Opening Images",
                description: "Use 'Open Folder...' from the File menu or press ⌘O to select a folder containing images. StillView will automatically scan the folder and display all supported image files.",
                shortcut: "⌘O",
                type: .information
            ),
            HelpContentItem(
                title: "Basic Navigation",
                description: "Once images are loaded, use the arrow keys or click the navigation controls to browse through your images. The current image position is shown in the top toolbar.",
                type: .information
            ),
            HelpContentItem(
                title: "Quick Start Tip",
                description: "For the best experience, organize your images in folders and use StillView's keyboard shortcuts for fast, distraction-free browsing. Try the thumbnail views ('T' and 'G') for quick navigation through large collections. All controls are now consolidated in the top toolbar for easy access.",
                type: .tip
            )
        ]
    )
    
    static let keyboardShortcuts = HelpSection(
        title: "Keyboard Shortcuts",
        icon: "keyboard",
        items: [
            HelpContentItem(
                title: "Open Folder",
                description: "Open a folder selection dialog",
                shortcut: "⌘O",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Next Image",
                description: "Navigate to the next image in the folder",
                shortcut: "→ or Space",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Previous Image",
                description: "Navigate to the previous image in the folder",
                shortcut: "←",
                type: .shortcut
            ),
            HelpContentItem(
                title: "First Image",
                description: "Jump to the first image in the folder",
                shortcut: "Home",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Last Image",
                description: "Jump to the last image in the folder",
                shortcut: "End",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Zoom In",
                description: "Increase image magnification",
                shortcut: "+ or =",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Zoom Out",
                description: "Decrease image magnification",
                shortcut: "-",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Fit to Window",
                description: "Scale image to fit within the window",
                shortcut: "0",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Actual Size",
                description: "Display image at 100% scale (actual pixels)",
                shortcut: "1",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Toggle Fullscreen",
                description: "Enter or exit fullscreen viewing mode",
                shortcut: "F or Enter",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Exit Fullscreen",
                description: "Exit fullscreen mode",
                shortcut: "Escape",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Show Image Info",
                description: "Toggle image metadata and EXIF information overlay",
                shortcut: "I",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Toggle Slideshow",
                description: "Start or stop automatic slideshow mode",
                shortcut: "S",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Thumbnail Strip",
                description: "Show/hide horizontal thumbnail strip at bottom",
                shortcut: "T",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Grid View",
                description: "Open full-screen thumbnail grid for quick navigation",
                shortcut: "G",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Delete Image",
                description: "Move current image to Trash (can be undone from Trash)",
                shortcut: "Delete or Backspace",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Back to Folder Selection",
                description: "Return to folder selection screen",
                shortcut: "Escape or B",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Help",
                description: "Show this help window",
                shortcut: "⌘?",
                type: .shortcut
            )
        ]
    )
    
    static let consolidatedToolbar = HelpSection(
        title: "Consolidated Toolbar",
        icon: "rectangle.3.group",
        items: [
            HelpContentItem(
                title: "Streamlined Design",
                description: "All controls are now organized in a single top toolbar for a cleaner, more intuitive interface. No more bottom toolbar taking up screen space.",
                type: .information
            ),
            HelpContentItem(
                title: "Left Section: Navigation & Context",
                description: "Contains the Back button, image counter (e.g., '4 of 4'), and folder selection button. Everything you need for navigation and context awareness.",
                type: .information
            ),
            HelpContentItem(
                title: "Center Section: View Mode Controls",
                description: "Groups all view-related toggles: Image Info (I), Slideshow (S), Thumbnail Strip (T), and Grid View (G). Easy to find and logically grouped.",
                type: .information
            ),
            HelpContentItem(
                title: "Right Section: Image Actions & Zoom",
                description: "Contains Share, Delete (trash), Zoom controls (-, zoom%, +, fit, 1:1), and filename toggle. All image manipulation tools in one place.",
                type: .information
            ),
            HelpContentItem(
                title: "Visual Separators",
                description: "Subtle dividers between toolbar sections help visually organize the controls while maintaining a clean, unified appearance.",
                type: .tip
            ),
            HelpContentItem(
                title: "Hover for Shortcuts",
                description: "Hover over any toolbar button to see its keyboard shortcut in a tooltip. This helps you learn the shortcuts for faster navigation.",
                type: .tip
            ),
            HelpContentItem(
                title: "macOS Native Design",
                description: "The consolidated toolbar follows macOS design patterns and works seamlessly with fullscreen mode, auto-hiding when appropriate.",
                type: .information
            )
        ]
    )
    
    static let navigation = HelpSection(
        title: "Interface & Controls",
        icon: "arrow.left.arrow.right",
        items: [
            HelpContentItem(
                title: "Browse Images",
                description: "Use arrow keys, spacebar, or navigation buttons to move between images. StillView automatically loads adjacent images for smooth browsing.",
                type: .information
            ),
            HelpContentItem(
                title: "Image Counter",
                description: "The top toolbar shows your current position (e.g., '5 of 23') in the left section next to the back button.",
                type: .information
            ),
            HelpContentItem(
                title: "Consolidated Toolbar",
                description: "All controls are now organized in a single top toolbar with three sections: Navigation & Context (left), View Mode Controls (center), and Image Actions & Zoom (right).",
                type: .information
            ),
            HelpContentItem(
                title: "Quick Navigation",
                description: "Use Home and End keys to quickly jump to the first or last image in the folder. Perfect for large image collections.",
                type: .tip
            ),
            HelpContentItem(
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
            HelpContentItem(
                title: "Thumbnail Strip",
                description: "Press 'T' or click the strip button in the center toolbar section to show a horizontal thumbnail strip at the bottom. Perfect for quick previews while maintaining focus on the main image.",
                shortcut: "T",
                type: .information
            ),
            HelpContentItem(
                title: "Grid View",
                description: "Press 'G' or click the grid button in the center toolbar section to open a full-screen thumbnail grid. Great for browsing large collections and jumping to specific images.",
                shortcut: "G",
                type: .information
            ),
            HelpContentItem(
                title: "Navigate with Thumbnails",
                description: "Click any thumbnail to instantly jump to that image. The current image is highlighted with a blue border and scroll position updates automatically.",
                type: .information
            ),
            HelpContentItem(
                title: "Thumbnail Performance",
                description: "Thumbnails are generated in the background and cached for smooth scrolling. The cache manages memory automatically to prevent system slowdowns.",
                type: .tip
            ),
            HelpContentItem(
                title: "Grid View Controls",
                description: "In grid view, use Escape to return to normal view, or click the grid button again in the toolbar. The grid shows image numbers, filenames, and file sizes for easy identification.",
                type: .information
            ),
            HelpContentItem(
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
            HelpContentItem(
                title: "Zoom Modes",
                description: "StillView offers multiple zoom modes: Fit to Window (default), Actual Size (100%), and custom zoom levels from 10% to 500%.",
                type: .information
            ),
            HelpContentItem(
                title: "Pan Large Images",
                description: "When zoomed in beyond window size, click and drag to pan around large images. Use trackpad gestures for natural navigation.",
                type: .information
            ),
            HelpContentItem(
                title: "Fullscreen Mode",
                description: "Press F or Enter for distraction-free fullscreen viewing. Press Escape to exit. Perfect for presentations or detailed image review.",
                type: .information
            ),
            HelpContentItem(
                title: "Automatic Fitting",
                description: "When loading new images, StillView automatically fits them to the window size for optimal viewing. You can then zoom as needed.",
                type: .tip
            ),
            HelpContentItem(
                title: "High DPI Support",
                description: "StillView automatically handles Retina displays and high-DPI images, ensuring crisp rendering at all zoom levels.",
                type: .information
            )
        ]
    )

    static let aiFeatures = HelpSection(
        title: "AI-Powered Insights (macOS 26+)",
        icon: "brain.head.profile",
        items: [
            HelpContentItem(
                title: "Intelligent Image Analysis",
                description: "StillView uses advanced on-device AI to understand your images. The system automatically analyzes image content, detects objects and scenes, recognizes text, evaluates quality, and generates smart tags—all processed locally on your Mac with no internet connection required.",
                type: .information
            ),
            HelpContentItem(
                title: "First-Time Setup",
                description: "When you first open StillView on macOS 26, you'll see a consent dialog explaining AI features. You can enable AI insights to unlock smart features or decline to use StillView without AI. Your choice is saved and can be changed anytime in Preferences.",
                type: .information
            ),
            HelpContentItem(
                title: "AI Insights Panel",
                description: "View comprehensive AI analysis by opening the AI Insights panel. See image classifications, detected objects (people, animals, vehicles), scene types (indoor/outdoor, nature/urban), recognized text with OCR, dominant colors and palettes, and quality assessments with enhancement suggestions.",
                type: .information
            ),
            HelpContentItem(
                title: "Smart Image Classification",
                description: "The AI automatically identifies what's in your images: primary subjects (people, animals, objects), scene contexts (beach, forest, city, indoor), activities and events, and visual themes. Each classification includes a confidence score showing the AI's certainty.",
                type: .information
            ),
            HelpContentItem(
                title: "Object Detection",
                description: "Advanced object detection locates and identifies specific items in your images: people and faces with positioning, animals and pets with species recognition, vehicles and transportation, common objects and items, and architectural elements. Objects are highlighted with confidence scores.",
                type: .information
            ),
            HelpContentItem(
                title: "Text Recognition (OCR)",
                description: "Extract text from images automatically with multi-language support. The AI recognizes printed and handwritten text, signs and labels, documents and receipts, and provides confidence scoring for recognized text. Perfect for finding images containing specific words or phrases.",
                type: .information
            ),
            HelpContentItem(
                title: "Scene Understanding",
                description: "The AI understands the context and setting of your images: indoor vs. outdoor classification, natural vs. urban environments, lighting conditions (day, night, sunset), weather and seasonal indicators, and location types (beach, mountains, city).",
                type: .information
            ),
            HelpContentItem(
                title: "Color Analysis",
                description: "Automatic color analysis identifies dominant colors with hex codes, complementary color palettes, color temperature (warm/cool), saturation and vibrancy levels, and color harmony patterns. Useful for design work and photo organization.",
                type: .information
            ),
            HelpContentItem(
                title: "Quality Assessment",
                description: "AI evaluates technical image quality including sharpness and focus analysis, exposure and lighting evaluation, resolution and detail assessment, noise and artifact detection, and composition suggestions. Get actionable recommendations for image enhancement.",
                type: .information
            ),
            HelpContentItem(
                title: "Smart Tags",
                description: "Automatically generated tags organize and categorize your images by content, themes, and characteristics. Tags are grouped by category (subjects, scenes, colors, activities) and can be used for quick search and filtering. Tags update in real-time as you browse.",
                type: .information
            ),
            HelpContentItem(
                title: "Actionable Insights",
                description: "The AI provides context-aware suggestions: enhancement recommendations (brightness, contrast, sharpness), organization ideas based on content patterns, similar image discovery for finding related photos, and smart search queries based on detected content.",
                type: .tip
            ),
            HelpContentItem(
                title: "Smart Search Integration",
                description: "AI analysis powers intelligent search capabilities. Search by detected objects and subjects, scene types and environments, recognized text content, colors and visual themes, and quality characteristics. Search suggestions appear as you type based on AI-detected content.",
                type: .information
            ),
            HelpContentItem(
                title: "Smart Organization",
                description: "AI helps automatically organize your image collection into smart categories (People, Animals, Nature, Food, Vehicles, Architecture, Sports, Art, Travel), time-based collections (daily, monthly), content-based groups, and similarity clusters for finding related images.",
                type: .information
            ),
            HelpContentItem(
                title: "Enhanced Accessibility",
                description: "AI generates comprehensive image descriptions for VoiceOver users: primary subject descriptions, detailed scene explanations, spatial relationship information, and multi-language support. Descriptions are optimized for screen readers with natural language flow.",
                type: .information
            ),
            HelpContentItem(
                title: "Privacy & Security",
                description: "All AI processing happens entirely on your Mac using Apple's Vision and Core ML frameworks. No data ever leaves your device—no internet connection required, no cloud processing, no data collection or tracking, and complete privacy for your images. AI features respect your privacy completely.",
                type: .information
            ),
            HelpContentItem(
                title: "Performance Optimization",
                description: "AI analysis is optimized for speed and efficiency: background processing doesn't block the UI, intelligent caching stores results for instant access, memory management prevents system slowdowns, and progressive analysis shows results as they're ready. Analysis typically completes in 1-2 seconds per image.",
                type: .tip
            ),
            HelpContentItem(
                title: "Enabling/Disabling AI",
                description: "Control AI features in Preferences > General. Toggle 'Enable AI Analysis' on or off. When disabled, StillView stops all AI processing immediately and clears cached insights. When re-enabled, the current image is automatically re-analyzed. Changes take effect instantly without restarting the app.",
                type: .information
            ),
            HelpContentItem(
                title: "AI Analysis Progress",
                description: "Watch real-time progress during analysis. A progress indicator shows analysis stages: image classification (20%), scene classification (40%), object detection (60%), text recognition (80%), color and quality analysis (100%). Results appear progressively as each stage completes.",
                type: .information
            ),
            HelpContentItem(
                title: "Error Handling",
                description: "If AI analysis fails (corrupted image, unsupported content, or system issues), StillView shows a clear error message with retry options. Most errors are temporary and can be resolved by retrying. The app continues working normally even if AI features encounter issues.",
                type: .information
            ),
            HelpContentItem(
                title: "System Requirements",
                description: "AI features require macOS 26.0 (Tahoe) or later with Apple Silicon or Intel Mac. Older macOS versions can still use StillView but without AI insights. The app automatically detects feature availability and shows appropriate messaging.",
                type: .warning
            ),
            HelpContentItem(
                title: "Testing Your Setup",
                description: "To verify AI features work correctly: Open any image and check for the AI Insights button in the toolbar, enable AI analysis in Preferences if disabled, view the AI Insights panel to see detected content, check that smart tags appear and update, and test smart search with detected objects or text.",
                type: .tip
            ),
            HelpContentItem(
                title: "Best Practices",
                description: "Get the most from AI features: allow initial analysis to complete for best accuracy, review smart tags and insights to understand AI capabilities, use smart search to quickly find specific image content, leverage quality assessments for photo improvement, and explore similar image suggestions for better organization.",
                type: .tip
            ),
            HelpContentItem(
                title: "Limitations",
                description: "AI analysis works best with clear, well-lit images. Very dark, blurry, or abstract images may have limited results. Text recognition requires readable text. Object detection works better with common subjects. Quality assessment is subjective and may not match artistic intent.",
                type: .warning
            )
        ]
    )

    static let preferences = HelpSection(
        title: "Preferences & Customization",
        icon: "gearshape",
        items: [
            HelpContentItem(
                title: "Opening Preferences",
                description: "Access preferences by pressing ⌘, (Command-Comma) or selecting 'Preferences...' from the StillView menu. The preferences window organizes settings into three main tabs.",
                shortcut: "⌘,",
                type: .information
            ),
            HelpContentItem(
                title: "General Settings",
                description: "Configure image display options (file names, info overlay), slideshow behavior (duration, looping), file management (deletion confirmation, folder memory), thumbnail preferences (size, metadata badges), and AI analysis settings (enable/disable AI features on macOS 26+).",
                type: .information
            ),
            HelpContentItem(
                title: "AI Features Control",
                description: "On macOS 26+, the General tab includes an 'Enable AI Analysis' toggle. Turn this on to enable intelligent image analysis, smart search, and organization features. Turn it off to disable all AI processing. Changes take effect immediately, and your preference is saved across app launches.",
                type: .information
            ),
            HelpContentItem(
                title: "Appearance Customization",
                description: "Personalize the interface with toolbar style options (floating vs. attached), animation intensity levels (minimal, normal, enhanced), glassmorphism effects, and hover feedback controls. Changes are previewed in real-time.",
                type: .information
            ),
            HelpContentItem(
                title: "Keyboard Shortcuts",
                description: "Customize all keyboard shortcuts to match your workflow. Click any shortcut to record a new key combination. The system automatically detects conflicts with existing shortcuts and system shortcuts.",
                type: .information
            ),
            HelpContentItem(
                title: "Live Preview",
                description: "The Appearance tab includes a live preview panel showing how your settings affect the toolbar, thumbnails, and notifications. Switch between preview modes to see different interface elements.",
                type: .tip
            ),
            HelpContentItem(
                title: "Shortcut Management",
                description: "Search for specific shortcuts using the search field. Reset individual shortcuts or all shortcuts to defaults. Export and import shortcut configurations to share between devices.",
                type: .information
            ),
            HelpContentItem(
                title: "Validation & Feedback",
                description: "Preferences include real-time validation with helpful error messages and warnings. Performance-impacting settings show warnings to help you make informed choices.",
                type: .information
            ),
            HelpContentItem(
                title: "Accessibility Integration",
                description: "All preference controls support full keyboard navigation and VoiceOver. Animation settings respect system accessibility preferences like Reduce Motion.",
                type: .information
            ),
            HelpContentItem(
                title: "Immediate Application",
                description: "Most preference changes take effect immediately without requiring an app restart. Settings are automatically saved and restored when you reopen the app.",
                type: .tip
            ),
            HelpContentItem(
                title: "Backup & Restore",
                description: "Preferences are automatically backed up before major changes. If settings become corrupted, the app will restore sensible defaults and notify you of the reset.",
                type: .information
            ),
            HelpContentItem(
                title: "Performance Optimization",
                description: "Enhanced animations and glass effects may impact performance on older Macs. The preferences system warns you about performance-heavy combinations and suggests alternatives.",
                type: .warning
            ),
            HelpContentItem(
                title: "Shortcut Conflicts",
                description: "When recording new shortcuts, the system checks for conflicts with existing app shortcuts and system shortcuts. Conflicting shortcuts are highlighted with suggestions for alternatives.",
                type: .warning
            )
        ]
    )
    
    static let additionalFeatures = HelpSection(
        title: "Image Management",
        icon: "star",
        items: [
            HelpContentItem(
                title: "Image Information",
                description: "Press 'I' or click the info button to display image metadata including dimensions, file size, format, creation date, and camera EXIF data when available.",
                shortcut: "I",
                type: .information
            ),
            HelpContentItem(
                title: "Slideshow Mode",
                description: "Press 'S' or click the play button to start an automatic slideshow. Images advance every 3 seconds by default. Press 'S' again or spacebar to pause/resume.",
                shortcut: "S",
                type: .information
            ),
            HelpContentItem(
                title: "Slideshow Controls",
                description: "During slideshow mode, spacebar pauses/resumes, and arrow keys allow manual navigation. The slideshow automatically loops back to the first image when reaching the end.",
                type: .information
            ),
            HelpContentItem(
                title: "Toolbar Organization",
                description: "The consolidated top toolbar groups related controls together: navigation on the left, view modes in the center, and image actions (share, delete, zoom) on the right. Hover over buttons for keyboard shortcut hints.",
                type: .information
            ),
            HelpContentItem(
                title: "Delete Images Safely",
                description: "Click the trash button or press Delete/Backspace to move images to Trash. A confirmation dialog ensures you don't accidentally delete images. Files can be recovered from the Trash.",
                type: .information
            ),
            HelpContentItem(
                title: "EXIF Data Support",
                description: "View detailed camera information including aperture, shutter speed, ISO, focal length, and GPS coordinates when available in the image metadata.",
                type: .tip
            ),
            HelpContentItem(
                title: "Share Images",
                description: "Use the share button in the top-right toolbar section to quickly share the current image via email, Messages, AirDrop, or other installed sharing services.",
                type: .information
            ),
            HelpContentItem(
                title: "Delete Images",
                description: "Click the trash button (between share and zoom controls) or press Delete/Backspace to move images to Trash. A confirmation dialog prevents accidental deletions.",
                type: .information
            ),
            HelpContentItem(
                title: "Safe File Management",
                description: "Deleted images are moved to the Trash, not permanently deleted. You can recover them from the Trash if needed. The app requires explicit folder access permissions for delete operations.",
                type: .tip
            ),
            HelpContentItem(
                title: "Auto-Navigation After Delete",
                description: "When you delete an image, StillView automatically advances to the next image in the folder. If you delete the last image, it will return to folder selection.",
                type: .information
            )
        ]
    )
    
    static let supportedFormats = HelpSection(
        title: "Supported Formats",
        icon: "photo",
        items: [
            HelpContentItem(
                title: "Primary Formats",
                description: "JPEG, PNG, GIF (including animated), HEIF/HEIC (iPhone photos), WebP",
                type: .information
            ),
            HelpContentItem(
                title: "Extended Formats",
                description: "TIFF, BMP, SVG, PDF (first page only)",
                type: .information
            ),
            HelpContentItem(
                title: "Modern iPhone Photos",
                description: "Full support for HEIF/HEIC format used by modern iPhones, including metadata and color profiles.",
                type: .information
            ),
            HelpContentItem(
                title: "Large Image Support",
                description: "StillView can handle very large images (100MB+) with intelligent memory management to prevent system slowdowns.",
                type: .information
            ),
            HelpContentItem(
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
            HelpContentItem(
                title: "Image Won't Load",
                description: "Ensure the file isn't corrupted and is in a supported format. StillView will automatically skip corrupted files and show the next valid image.",
                type: .warning
            ),
            HelpContentItem(
                title: "Memory Warnings",
                description: "If you see memory warnings, try closing other applications or restart StillView. Very large images (>100MB) may require more available system memory.",
                type: .warning
            ),
            HelpContentItem(
                title: "Folder Access Issues",
                description: "StillView uses security-scoped bookmarks to remember folder access. If you can't access a previously selected folder, try selecting it again.",
                type: .information
            ),
            HelpContentItem(
                title: "Delete Permission Issues",
                description: "If you see 'Permission denied' when trying to delete images, the app needs write access to the folder. Simply re-select the folder using the folder button in the top toolbar to restore delete permissions.",
                type: .warning
            ),
            HelpContentItem(
                title: "Performance Tips",
                description: "For best performance with large image collections, ensure your Mac has sufficient RAM and consider organizing images into smaller folders (100-500 images per folder). Thumbnail views work best with collections under 1000 images.",
                type: .tip
            ),
            HelpContentItem(
                title: "Thumbnail Loading",
                description: "Thumbnails generate automatically in the background. Large images may take a moment to appear in thumbnail views. The thumbnail cache persists between sessions for faster subsequent loading.",
                type: .information
            ),
            HelpContentItem(
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
            HelpContentItem(
                title: "Privacy First",
                description: "StillView works completely offline and never collects or transmits any data. Your images and viewing habits remain completely private. All AI processing (on macOS 26+) happens entirely on your device using Apple's frameworks—no cloud services, no data collection, no tracking.",
                type: .information
            ),
            HelpContentItem(
                title: "AI Privacy Commitment",
                description: "AI features (macOS 26+) use only Apple's built-in Vision and Core ML frameworks running locally on your Mac. No image data ever leaves your device. No analytics, telemetry, or usage tracking. You have complete control to enable or disable AI features at any time in Preferences.",
                type: .information
            ),
            HelpContentItem(
                title: "Universal Binary",
                description: "Optimized for both Intel and Apple Silicon Macs, ensuring excellent performance on all modern Mac computers. AI features on macOS 26+ leverage Neural Engine on Apple Silicon for enhanced performance.",
                type: .information
            ),
            HelpContentItem(
                title: "Accessibility",
                description: "Full VoiceOver support, keyboard navigation, and compatibility with macOS accessibility features. AI-powered image descriptions (macOS 26+) provide enhanced VoiceOver experiences with detailed, context-aware descriptions of image content.",
                type: .information
            ),
            HelpContentItem(
                title: "Open Source",
                description: "StillView is open source software. Visit the GitHub repository for source code, issues, and contributions at github.com/vscarpenter/SimpleImageViewer.",
                type: .information
            ),
            HelpContentItem(
                title: "Support",
                description: "For support, bug reports, or feature requests, visit the GitHub Issues page or contact the developer through the repository. For AI-related questions, see the AI Features section of this help guide.",
                type: .information
            ),
            HelpContentItem(
                title: "App Sandbox Security",
                description: "StillView operates within Apple's App Sandbox for enhanced security. The app only accesses folders you explicitly select and requires your permission for file operations. All security-scoped bookmarks are stored locally and encrypted.",
                type: .information
            )
        ]
    )
}

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
                description: "Navigate to the next image; Space stops an active slideshow",
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
                description: "F toggles fullscreen; Enter opens the selection in Grid and toggles fullscreen in Single or Strip",
                shortcut: "F or Enter",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Step Back",
                description: "Exit fullscreen, or return from Grid or Strip to Single. Escape does not return to folder selection.",
                shortcut: "Escape",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Toggle Inspector",
                description: "Show/hide the Info & Insights inspector panel",
                shortcut: "I",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Show AI Insights",
                description: "Open the inspector on the Insights tab",
                shortcut: "⌘I",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Toggle Slideshow",
                description: "Start or stop automatic slideshow mode",
                shortcut: "S",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Strip View",
                description: "Show the docked filmstrip view",
                shortcut: "T",
                type: .shortcut
            ),
            HelpContentItem(
                title: "Grid View",
                description: "Browse all images in a grid; Esc or Enter returns to Single",
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
                shortcut: "B",
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
        title: "Toolbar",
        icon: "rectangle.3.group",
        items: [
            HelpContentItem(
                title: "Folder and Image Counter",
                description: "Use the folder menu on the left to choose another folder or reopen a recent one. The counter shows your position in the current collection.",
                type: .information
            ),
            HelpContentItem(
                title: "Single, Strip, and Grid",
                description: "Choose Single to focus on one image, Strip to add a docked filmstrip, or Grid to browse thumbnails in the viewing area. Narrow windows show icons for these modes.",
                type: .information
            ),
            HelpContentItem(
                title: "Image Actions",
                description: "The toolbar provides slideshow, sharing, Trash, and inspector controls. Single and Strip include zoom controls; Grid includes thumbnail density and sorting.",
                type: .information
            ),
            HelpContentItem(
                title: "Compact Windows",
                description: "In narrow windows, use the toolbar’s More actions menu for additional image actions and view controls.",
                type: .information
            ),
            HelpContentItem(
                title: "Keyboard Shortcuts",
                description: "Hover over a control for its label or shortcut. Press B to return to folder selection, or use File → Back to Folder Selection.",
                type: .tip
            )
        ]
    )

    static let navigation = HelpSection(
        title: "Interface & Controls",
        icon: "arrow.left.arrow.right",
        items: [
            HelpContentItem(
                title: "Browse Images",
                description: "With the image viewer focused, use arrow keys or the image-stage navigation arrows to browse. Home and End jump to the first and last image.",
                type: .information
            ),
            HelpContentItem(
                title: "Image Counter",
                description: "The folder menu and image counter are at the left of the toolbar.",
                type: .information
            ),
            HelpContentItem(
                title: "Refresh a Folder",
                description: "Choose the folder again to refresh images added or removed outside StillView. Folder contents do not refresh automatically.",
                type: .information
            ),
            HelpContentItem(
                title: "Return to Folder Selection",
                description: "Press B while the viewer is focused, or use File → Back to Folder Selection. Opening another folder with ⌘O keeps the current image available if you cancel.",
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
                description: "Press T or choose Strip in the toolbar. Click a thumbnail in the docked filmstrip to view that image.",
                type: .information
            ),
            HelpContentItem(
                title: "Grid View",
                description: "Press G or choose Grid in the toolbar to browse thumbnails in the viewing area. The selected image uses your system accent color.",
                type: .information
            ),
            HelpContentItem(
                title: "Open a Grid Selection",
                description: "Click a tile to select it; the inspector follows the selection. Double-click or press Enter to open it in Single view. Escape returns to Single when not in fullscreen.",
                type: .information
            ),
            HelpContentItem(
                title: "Grid Controls",
                description: "Use the toolbar’s density slider to resize thumbnails. In a narrow window, sorting is available in the More actions menu.",
                type: .information
            ),
            HelpContentItem(
                title: "Thumbnail Loading",
                description: "Thumbnails are downsampled in the background and regenerated as needed. Large files may take a moment to appear.",
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
                description: "Use Fit to Window (0), Actual Size (1), or the zoom controls to inspect image details.",
                type: .information
            ),
            HelpContentItem(
                title: "Pan Large Images",
                description: "When zoomed in beyond window size, click and drag to pan around large images. Use trackpad gestures for natural navigation.",
                type: .information
            ),
            HelpContentItem(
                title: "Fullscreen Mode",
                description: "Press F to enter or exit fullscreen. Enter also toggles fullscreen in Single and Strip; in Grid, Enter opens the selected image. Escape exits fullscreen.",
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
        title: "AI Insights",
        icon: "brain.head.profile",
        items: [
            HelpContentItem(
                title: "Generate an Insight",
                description: "Open the inspector with I, choose Insights, and select Generate Insight. You can also press ⌘I while the viewer has focus. If Insights are disabled in StillView, choose Enable Insights first.",
                type: .information
            ),
            HelpContentItem(
                title: "Visual Matches and Text",
                description: "Apple Vision analyzes the current image on this Mac for image categories, recognized text (OCR), and face counts. Results include confidence-based matches and limits; face detection does not identify people.",
                type: .information
            ),
            HelpContentItem(
                title: "Apple Intelligence Text Selection",
                description: "When useful recognized text is available, Apple’s on-device Foundation Models framework can select up to three existing OCR lines. StillView displays those exact lines without rewriting them. The language model does not receive image pixels.",
                type: .information
            ),
            HelpContentItem(
                title: "Privacy",
                description: "StillView does not upload images, metadata, prompts, recognized text, or results. Analysis runs on this Mac without analytics or telemetry.",
                type: .information
            ),
            HelpContentItem(
                title: "Enable or Disable Insights",
                description: "Use Settings → Intelligence → AI Insights, or enable them from the Insights panel. Disabling them cancels generation; the panel can still explain how to enable the feature.",
                type: .information
            ),
            HelpContentItem(
                title: "Availability",
                description: "AI Insights require an Apple Intelligence eligible Mac, Apple Intelligence enabled in System Settings, and an on-device model that is ready. StillView shows the reason when generation is unavailable.",
                type: .information
            ),
            HelpContentItem(
                title: "Limitations",
                description: "Visual matches may be incomplete or incorrect, and recognized text may contain OCR errors. The feature does not identify people, organize files, perform smart search, or generate a free-form description of unseen image details.",
                type: .warning
            )
        ]
    )

    static let preferences = HelpSection(
        title: "Settings",
        icon: "gearshape",
        items: [
            HelpContentItem(
                title: "Opening Settings",
                description: "Press ⌘, (Command-Comma) or choose Settings from the StillView menu. General, Intelligence, and Shortcuts organize the available settings.",
                type: .information
            ),
            HelpContentItem(
                title: "Image Display Defaults",
                description: "Choose whether file names and the inspector appear by default. These settings apply when you next launch StillView.",
                type: .information
            ),
            HelpContentItem(
                title: "Slideshow Duration",
                description: "Choose how long each image appears in a slideshow. Duration changes apply when you next launch StillView. Slideshows repeat from the first image after the last image.",
                type: .information
            ),
            HelpContentItem(
                title: "Insights and Enhancements",
                description: "Enable or disable AI Insights and automatic image enhancements in Intelligence. Enhancements affect the displayed image and preserve the original file.",
                type: .information
            ),
            HelpContentItem(
                title: "Appearance",
                description: "Settings follows your Mac’s light or dark appearance, accessibility options, and system control colors.",
                type: .information
            ),
            HelpContentItem(
                title: "Built-in Keyboard Shortcuts",
                description: "The Shortcuts tab is a searchable, read-only reference to the viewer’s built-in commands. Image commands work when the viewer is focused; text fields, controls, dialogs, and other windows retain their usual keys.",
                type: .information
            ),
            HelpContentItem(
                title: "Saved Settings",
                description: "Settings are saved automatically. Image display defaults and slideshow duration take effect on the next launch.",
                type: .tip
            )
        ]
    )

    static let additionalFeatures = HelpSection(
        title: "Image Management",
        icon: "star",
        items: [
            HelpContentItem(
                title: "Image Information",
                description: "Press I or use the inspector button to open the Info and Insights panel. Info shows file details, dimensions, color information, and EXIF camera data when available.",
                type: .information
            ),
            HelpContentItem(
                title: "Slideshow",
                description: "Press S to start or stop a slideshow. Space stops an active slideshow; otherwise it advances to the next image. Slideshows repeat after the last image.",
                type: .information
            ),
            HelpContentItem(
                title: "Share Images",
                description: "Use Share in the toolbar or its More actions menu to open macOS sharing services for the current image. Sharing is a user-initiated action.",
                type: .information
            ),
            HelpContentItem(
                title: "Move Images to Trash",
                description: "Use Move to Trash or press Delete/Backspace with the viewer focused. Confirm the named file in the dialog. You can recover that file from macOS Trash.",
                type: .information
            ),
            HelpContentItem(
                title: "Folder Permissions",
                description: "StillView requests access to folders you select. Read-write access allows the app to move a confirmed image to Trash; it does not rewrite your original image for viewing or enhancements.",
                type: .information
            ),
            HelpContentItem(
                title: "After Moving to Trash",
                description: "StillView removes the trashed file from the open collection. If it was the selected image, another image is selected when available. An empty collection returns to folder selection.",
                type: .information
            )
        ]
    )

    static let supportedFormats = HelpSection(
        title: "Supported Formats",
        icon: "photo",
        items: [
            HelpContentItem(
                title: "Image Formats",
                description: "JPEG, PNG, GIF, HEIF/HEIC, WebP, TIFF, and BMP.",
                type: .information
            ),
            HelpContentItem(
                title: "Still Images",
                description: "Animated GIF and WebP files display their first frame only. Multipage TIFF files display their first image. Animation playback and additional pages are not supported.",
                type: .information
            ),
            HelpContentItem(
                title: "Unsupported Formats",
                description: "SVG and PDF files are not supported and do not appear in the folder’s image collection.",
                type: .information
            ),
            HelpContentItem(
                title: "Metadata",
                description: "The Info inspector displays the metadata available in each file. Different formats and files may contain different fields.",
                type: .information
            ),
            HelpContentItem(
                title: "Large Images",
                description: "Large or damaged files may take longer to load or fail to decode. Use the displayed error and retry action if an image cannot be opened.",
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
                description: "Check that the file is readable and uses a supported format. Use Retry if loading fails, or navigate to another image.",
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
                description: "Thumbnails are downsampled in the background and regenerated as needed. Large files may take a moment to appear.",
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
                description: "StillView does not collect data or use tracking. Image viewing and analysis work locally. Sharing and external links open only when you choose them. Privacy policy: https://stillviewapp.com/privacy.html",
                type: .information
            ),
            HelpContentItem(
                title: "AI Privacy Commitment",
                description: "AI Insights uses on-device Vision for visual matches, OCR, and face counts. Apple Intelligence can select exact existing OCR lines without receiving image pixels. Inputs and results stay on this Mac. You can disable Insights in Settings → Intelligence.",
                type: .information
            ),
            HelpContentItem(
                title: "Universal Binary",
                description: "StillView requires macOS 26 or later and includes Intel and Apple Silicon builds. AI Insights additionally requires Apple Intelligence support.",
                type: .information
            ),
            HelpContentItem(
                title: "Accessibility",
                description: "StillView includes keyboard navigation, accessibility labels, and support for Reduce Motion. Image descriptions use local metadata without uploading image data.",
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
                description: "StillView operates within Apple's App Sandbox for enhanced security. The app only accesses folders you explicitly select and requires your permission for file operations. Security-scoped bookmarks are stored locally.",
                type: .information
            )
        ]
    )
}

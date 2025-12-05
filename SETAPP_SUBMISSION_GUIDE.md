# Setapp Submission Guide

This document outlines the complete process for submitting StillView to Setapp for distribution.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Phase 1: Prepare Setapp Build Configuration](#phase-1-prepare-setapp-build-configuration)
- [Phase 2: Build and Notarization](#phase-2-build-and-notarization)
- [Phase 3: Package for Setapp](#phase-3-package-for-setapp)
- [Phase 4: Submit to Setapp](#phase-4-submit-to-setapp)
- [Ongoing Maintenance](#ongoing-maintenance)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts & Certificates

- [ ] Apple Developer Account with Developer ID Application certificate
- [ ] Setapp Developer Account (https://developer.setapp.com)
- [ ] App-specific password generated for notarization
- [ ] Team ID from Apple Developer account

### Current App Configuration

- **Bundle ID**: `com.vinny.StillView-Image-Viewer`
- **Current Version**: 2.5.4 (Build 20)
- **Mac App Store Target**: macOS 12.0+
- **Setapp Target**: macOS 10.13+ (recommended for wider compatibility)

### Key Differences: App Store vs Setapp

| Aspect | Mac App Store | Setapp |
|--------|--------------|--------|
| Code Signing | App Store certificate | Developer ID Application |
| Sandboxing | Required | Optional (but supported) |
| Notarization | Required | Required |
| Binary Type | Universal | Universal |
| Minimum macOS | 12.0+ (current) | 10.13+ (recommended) |
| Updates | App Store | Setapp framework |
| Licensing | None (paid app) | Managed by Setapp |

---

## Phase 1: Prepare Setapp Build Configuration

### Step 1.1: Create Setapp Build Scheme

1. Open `StillView - Simple Image Viewer.xcodeproj` in Xcode
2. Navigate to **Product → Scheme → Manage Schemes**
3. Duplicate the existing scheme:
   - Select "StillView - Simple Image Viewer"
   - Click the gear icon → Duplicate
   - Rename to "StillView - Setapp"
4. Edit the new scheme:
   - Set Build Configuration to "Release"
   - Ensure "Archive" uses Release configuration

### Step 1.2: Create Setapp Build Configuration (Optional)

If you need different settings for Setapp:

1. In project settings, duplicate "Release" configuration
2. Name it "Setapp Release"
3. Modify settings as needed:
   - Code signing: Developer ID Application
   - Provisioning profile: None (use automatic signing)
   - Deployment target: macOS 10.13 (if lowering minimum version)

### Step 1.3: Update Entitlements (If Needed)

Current entitlements (`Simple_Image_Viewer.entitlements`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
	<key>com.apple.security.files.bookmarks.app-scope</key>
	<true/>
</dict>
</plist>
```

**For Setapp**: These entitlements are compatible. No changes required unless you need additional capabilities.

Optional additions for future features:
- `com.apple.security.network.client` - for network access
- `com.apple.security.network.server` - for local server functionality

### Step 1.4: Create Export Options Plist

Create file: `ExportOptions-Setapp.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>YOUR_TEAM_ID</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>compileBitcode</key>
	<false/>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
```

**Replace `YOUR_TEAM_ID`** with your actual Apple Developer Team ID.

---

## Phase 2: Build and Notarization

### Step 2.1: Create Archive

#### Option A: Using Xcode GUI

1. Select scheme: "StillView - Setapp"
2. Select destination: "Any Mac"
3. **Product → Archive**
4. Wait for archive to complete
5. Organizer window will open automatically

#### Option B: Using Command Line

```bash
# Navigate to project directory
cd /Users/vinnycarpenter/Projects/SimpleImageViewer

# Create archive
xcodebuild archive \
  -project "StillView - Simple Image Viewer.xcodeproj" \
  -scheme "StillView - Setapp" \
  -archivePath "./build/StillView-Setapp.xcarchive" \
  -configuration Release \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
  CODE_SIGN_IDENTITY="Developer ID Application"
```

### Step 2.2: Export Archive

#### Option A: Using Xcode GUI

1. In Organizer, select the archive
2. Click **Distribute App**
3. Select **Developer ID**
4. Choose **Export**
5. Select signing options (automatic recommended)
6. Click **Export**
7. Choose destination folder

#### Option B: Using Command Line

```bash
# Export the archive
xcodebuild -exportArchive \
  -archivePath "./build/StillView-Setapp.xcarchive" \
  -exportPath "./build/StillView-Setapp" \
  -exportOptionsPlist "ExportOptions-Setapp.plist"
```

The exported app will be at: `./build/StillView-Setapp/StillView - Simple Image Viewer.app`

### Step 2.3: Notarize the App

#### Step 2.3.1: Generate App-Specific Password (One-Time)

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Navigate to **Security → App-Specific Passwords**
4. Click **Generate Password**
5. Label it "Setapp Notarization"
6. Save the generated password securely

#### Step 2.3.2: Store Credentials in Keychain (Recommended)

```bash
# Store credentials for easier notarization
xcrun notarytool store-credentials "setapp-notarization" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

#### Step 2.3.3: Submit for Notarization

```bash
# Navigate to the exported app directory
cd ./build/StillView-Setapp

# Create a ZIP for notarization
ditto -c -k --keepParent "StillView - Simple Image Viewer.app" "StillView.zip"

# Submit for notarization (using stored credentials)
xcrun notarytool submit "StillView.zip" \
  --keychain-profile "setapp-notarization" \
  --wait

# OR submit without stored credentials
xcrun notarytool submit "StillView.zip" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait
```

**Expected output:**
```
Conducting pre-submission checks for StillView.zip and initiating connection to the Apple notary service...
Submission ID received
  id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Successfully uploaded file
  id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  path: /path/to/StillView.zip
Waiting for processing to complete.
Current status: In Progress....
Current status: Accepted

Processing complete
  id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  status: Accepted
```

#### Step 2.3.4: Check Notarization Status (If Needed)

```bash
# Get submission info
xcrun notarytool info SUBMISSION_ID \
  --keychain-profile "setapp-notarization"

# Get detailed log (if there are issues)
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "setapp-notarization" \
  developer_log.json
```

#### Step 2.3.5: Staple Notarization Ticket

```bash
# Staple the notarization ticket to the app
xcrun stapler staple "StillView - Simple Image Viewer.app"

# Verify stapling
xcrun stapler validate "StillView - Simple Image Viewer.app"
```

**Expected output:**
```
The validate action worked!
```

#### Step 2.3.6: Verify Code Signature

```bash
# Verify the app signature
codesign --verify --deep --strict "StillView - Simple Image Viewer.app"
codesign --display --verbose=4 "StillView - Simple Image Viewer.app"

# Check if app is notarized
spctl --assess --verbose=4 "StillView - Simple Image Viewer.app"
```

**Expected output:**
```
StillView - Simple Image Viewer.app: accepted
source=Notarized Developer ID
```

---

## Phase 3: Package for Setapp

### Step 3.1: Prepare App Bundle

Setapp requirements:
- Maximum size: 1 GB
- Bundle must be in root directory or single nested directory
- Matching bundle ID for updates

#### Check Bundle Size

```bash
# Check app size
du -sh "StillView - Simple Image Viewer.app"

# Check if under 1GB limit
du -sm "StillView - Simple Image Viewer.app" | awk '{if($1 > 1024) print "WARNING: Over 1GB"; else print "OK: Under 1GB"}'
```

#### Create ZIP Archive

```bash
# Create properly formatted ZIP for Setapp
ditto -c -k --keepParent "StillView - Simple Image Viewer.app" "StillView-Setapp-v2.5.4.zip"

# Verify ZIP contents
unzip -l "StillView-Setapp-v2.5.4.zip" | head -20
```

### Step 3.2: Prepare App Icon

Setapp requirements:
- Size: 512 x 512 pixels minimum
- Format: PNG
- Filename: `AppIcon.png`
- 50-pixel margin around the icon
- Curved corners

#### Extract Icon from App

```bash
# Option 1: Use iconutil (if you have .icns file)
iconutil -c iconset "StillView - Simple Image Viewer.app/Contents/Resources/AppIcon.icns"

# Option 2: Extract from Assets.xcassets
# Navigate to: StillView - Simple Image Viewer/Assets.xcassets/AppIcon.appiconset/
# Export the 512x512 PNG manually from Xcode
```

#### Verify Icon Specifications

- Open the exported PNG in Preview or image editor
- Verify dimensions: 512 x 512 pixels
- Ensure 50px margin on all sides
- Save as `AppIcon.png`

### Step 3.3: Prepare Screenshots

Setapp requirements:
- **Quantity**: 5 screenshots for macOS
- **Format**: PNG or JPEG
- **Recommended size**: 1280 x 800 or higher
- **Content**: Show key features and UI

#### Screenshot Checklist

1. **Main image viewing interface** - Show primary image display
2. **Thumbnail grid view** - Demonstrate organization features
3. **AI Insights panel** (macOS 26+) - Highlight AI analysis features
4. **Keyboard shortcuts/Help** - Show accessibility features
5. **Preferences/Settings** - Display customization options

#### Capture Screenshots

```bash
# Take screenshots with macOS screenshot tool
# Press Cmd+Shift+4, then Spacebar to capture window
# Or use Cmd+Shift+5 for screenshot utility

# Name them descriptively:
# - screenshot-1-main-view.png
# - screenshot-2-grid-view.png
# - screenshot-3-ai-insights.png
# - screenshot-4-help-system.png
# - screenshot-5-preferences.png
```

---

## Phase 4: Submit to Setapp

### Step 4.1: Access Setapp Developer Portal

1. Navigate to https://developer.setapp.com
2. Sign in with your Setapp developer account
3. If no account, create one at https://developer.setapp.com/signup

### Step 4.2: Create New App Submission

1. Click **Add New App** or **Submit New App**
2. Choose **macOS App**
3. Enter basic information:
   - App name: **StillView - Simple Image Viewer**
   - Bundle ID: `com.vinny.StillView-Image-Viewer`
   - Category: Photography

### Step 4.3: Upload Build

1. Drag and drop `StillView-Setapp-v2.5.4.zip` to upload area
2. Wait for upload to complete
3. Setapp will verify:
   - Code signing with Developer ID
   - Notarization status
   - Bundle ID match
   - File size under 1 GB

### Step 4.4: Complete App Metadata

#### App Information

**App Name**:
```
StillView - Simple Image Viewer
```

**Subtitle** (short description):
```
Elegant, distraction-free image viewer for macOS with AI-powered insights
```

**Key Benefits** (3-5 bullet points):
```
• Effortless browsing through entire folders with keyboard-first navigation
• AI-powered image analysis with object detection and quality assessment (macOS 26+)
• Universal format support: JPEG, PNG, GIF, HEIF, WebP, TIFF, BMP, SVG
• Advanced viewing modes: thumbnail grid, slideshow, and detailed metadata overlay
• Complete privacy: works offline, no data collection, sandboxed security
```

**Description** (detailed, from README):
```
A minimalist, elegant image viewer designed specifically for macOS users who want a clean, distraction-free way to browse through image collections. Built with SwiftUI and optimized for native macOS experience with advanced features like thumbnail navigation, slideshow mode, AI-powered insights, and comprehensive accessibility support.

EFFORTLESS BROWSING
Browse through entire folders of images with intuitive keyboard shortcuts. No complex menus or overwhelming interfaces—just pure image viewing.

KEYBOARD-FIRST DESIGN
Navigate with arrow keys, zoom with +/-, toggle fullscreen with F, start slideshow with S, and access comprehensive help with ⌘?. Every feature is accessible from your keyboard.

AI-POWERED IMAGE ANALYSIS (macOS 26+)
Revolutionary on-device AI analyzes your images to identify objects, scenes, text, colors, and quality—all processed locally with complete privacy. Smart tags, enhanced accessibility descriptions, and quality assessments powered by Vision and Core ML.

UNIVERSAL FORMAT SUPPORT
View all your images with crystal-clear quality:
• Primary: JPEG, PNG, GIF (animated), HEIF/HEIC, WebP
• Extended: TIFF, BMP, SVG, PDF (first page)

ADVANCED VIEWING MODES
• Thumbnail Strip: Horizontal filmstrip for quick navigation
• Grid View: Full-screen thumbnail grid for large collections
• Slideshow Mode: Automatic progression with customizable timing
• Image Information: Detailed metadata and EXIF data overlay
• Pan & Zoom: Smooth navigation of high-resolution images

MACOS NATIVE EXPERIENCE
Full VoiceOver and accessibility support with AI-generated detailed image descriptions, high contrast mode compatibility, reduced motion preferences respected, and native macOS design language with modern SF Symbols.

PRIVACY & SECURITY
No internet required—works completely offline. No data collection or tracking. App Sandbox enabled for maximum security. Only accesses folders you explicitly select. All AI processing happens on your device.
```

**System Requirements**:
```
macOS 10.13 (High Sierra) or later
Universal Binary (Intel and Apple Silicon)
4GB RAM minimum (8GB recommended for large collections)
```

**Version & Release Notes**:
```
Version: 2.5.4

What's New:
• Enhanced AI Image Analysis – Updated ResNet50 Core ML model delivers more accurate object detection and scene classification
• Improved Memory Performance – Increased memory limits prevent errors when browsing large image collections
• More Reliable AI Insights – Enhanced detection accuracy for people, faces, and food photography
• Performance Optimizations – Refined AI processing pipeline for faster analysis and smoother browsing
```

#### URLs

**Support URL**:
```
https://github.com/vscarpenter/SimpleImageViewer/issues
```

**Promo URL** (optional):
```
https://vinny.dev
```

**Privacy Policy URL** (if applicable):
```
https://github.com/vscarpenter/SimpleImageViewer#-security--privacy
```

#### Screenshots

Upload the 5 prepared screenshots in order:
1. Main image viewing interface
2. Thumbnail grid view
3. AI Insights panel
4. Help system / Keyboard shortcuts
5. Preferences / Settings

#### App Icon

Upload `AppIcon.png` (512 x 512 pixels with 50px margin)

#### Review Team Comments (Internal Notes)

```
StillView is a native macOS image viewer built with SwiftUI, designed for Mac App Store distribution but also compatible with Setapp.

Key technical details:
- Universal binary supporting Intel and Apple Silicon
- Sandboxed with minimal entitlements (user-selected file access)
- Signed with Developer ID and notarized
- AI features require macOS 26+ (graceful fallback on older systems)
- No network access, completely offline functionality
- No licensing or activation mechanisms (fully functional)

The app is fully functional with no trial limitations, paid features, or in-app purchases. All features are available immediately upon launch.

Test scenarios:
1. Open app and select a folder containing images
2. Navigate with arrow keys and keyboard shortcuts
3. Toggle thumbnail grid (G), slideshow (S), and fullscreen (F)
4. On macOS 26+, test AI insights panel for image analysis
5. Verify VoiceOver accessibility support
```

### Step 4.5: Submit for Review

1. Review all entered information
2. Check that all required fields are complete
3. Verify screenshots and icon look correct
4. Click **Submit for Review**
5. Await Setapp review team response

**Expected timeline:**
- Initial review: 1-2 weeks
- Subsequent updates: 3-5 days

---

## Ongoing Maintenance

### Submitting Updates

1. **Update version number** in Xcode:
   - Increment `MARKETING_VERSION` (e.g., 2.5.4 → 2.5.5)
   - Increment `CURRENT_PROJECT_VERSION` (build number)

2. **Repeat Phase 2**: Build and notarization
   - Use same process for creating archive
   - Notarize new build

3. **Repeat Phase 3**: Package for Setapp
   - Create new ZIP with updated version
   - Update screenshots if UI changed

4. **Upload to Setapp**:
   - Log in to developer portal
   - Navigate to app page
   - Click **Upload New Build**
   - Same bundle ID will link it to existing app
   - Add release notes
   - Submit for review

### Managing Both App Store and Setapp

**Version Parity**: Keep versions synchronized
```
App Store version: 2.5.4 (Build 20)
Setapp version: 2.5.4 (Build 20)
```

**Build Process**:
1. Create App Store build first (standard process)
2. Submit to App Store Connect
3. Immediately create Setapp build from same commit
4. Submit to Setapp

**Testing**:
- Test App Store build on macOS 12.0+
- Test Setapp build on macOS 10.13+ (if supporting older versions)
- Verify both builds have identical functionality

**Release Notes**: Maintain single source of truth
- Use same release notes for both platforms
- Store in `whats-new.json` for in-app display
- Copy to both App Store and Setapp submissions

---

## Troubleshooting

### Notarization Issues

#### Error: "The binary is not signed"
```bash
# Re-sign the app
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" "StillView - Simple Image Viewer.app"
```

#### Error: "The signature does not include a secure timestamp"
```bash
# Add timestamp to signing
codesign --force --deep --timestamp --options runtime \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "StillView - Simple Image Viewer.app"
```

#### Error: "The app bundle is invalid"
- Check Info.plist for required keys
- Verify bundle structure: `Contents/MacOS/`, `Contents/Resources/`
- Ensure CFBundleVersion and CFBundleShortVersionString are set

### Setapp Upload Issues

#### Error: "Bundle ID mismatch"
- Verify bundle ID in Xcode matches Setapp submission
- Check Info.plist: `CFBundleIdentifier`

#### Error: "File too large"
```bash
# Check file size
du -sh "StillView - Simple Image Viewer.app"

# Reduce size by:
# - Removing unused assets
# - Stripping debug symbols (already done in Release)
# - Compressing resources
```

#### Error: "App not notarized"
```bash
# Verify notarization
xcrun stapler validate "StillView - Simple Image Viewer.app"

# Re-staple if needed
xcrun stapler staple "StillView - Simple Image Viewer.app"
```

### Code Signing Issues

#### Finding Your Team ID
```bash
# List available certificates
security find-identity -v -p codesigning

# Or check in Xcode:
# Xcode → Preferences → Accounts → Manage Certificates
```

#### Developer ID Not Found
- Ensure you have a valid Apple Developer Program membership
- Generate Developer ID Application certificate at https://developer.apple.com/account
- Download and install certificate in Keychain Access

### Build Issues

#### Scheme Not Found
```bash
# List available schemes
xcodebuild -list -project "StillView - Simple Image Viewer.xcodeproj"

# Create scheme if needed (in Xcode)
# Product → Scheme → New Scheme
```

#### Architecture Issues
```bash
# Verify Universal Binary
lipo -info "StillView - Simple Image Viewer.app/Contents/MacOS/StillView - Simple Image Viewer"

# Expected output:
# Non-fat file (arm64) or Architectures: x86_64 arm64
```

### Setapp-Specific Issues

#### App Rejected: "Contains licensing mechanisms"
- Remove any license validation code
- Remove any "Pro" or "Premium" feature flags
- Ensure all features are immediately accessible

#### App Rejected: "Contains in-app purchases"
- Remove StoreKit framework if present
- Remove any purchase-related UI or code

#### App Rejected: "Requires internet connection"
- Ensure app works fully offline
- Remove any network requirements from startup

---

## Quick Reference

### File Locations
```
Project: /Users/vinnycarpenter/Projects/SimpleImageViewer
Xcode Project: StillView - Simple Image Viewer.xcodeproj
Entitlements: StillView - Simple Image Viewer/Simple_Image_Viewer.entitlements
Export Options: ExportOptions-Setapp.plist (create this)
Build Output: ./build/StillView-Setapp/
```

### Key Commands

**Build Archive:**
```bash
xcodebuild archive -project "StillView - Simple Image Viewer.xcodeproj" \
  -scheme "StillView - Setapp" -archivePath "./build/StillView-Setapp.xcarchive" \
  -configuration Release
```

**Export Archive:**
```bash
xcodebuild -exportArchive -archivePath "./build/StillView-Setapp.xcarchive" \
  -exportPath "./build/StillView-Setapp" -exportOptionsPlist "ExportOptions-Setapp.plist"
```

**Notarize:**
```bash
ditto -c -k --keepParent "StillView - Simple Image Viewer.app" "StillView.zip"
xcrun notarytool submit "StillView.zip" --keychain-profile "setapp-notarization" --wait
xcrun stapler staple "StillView - Simple Image Viewer.app"
```

**Verify:**
```bash
codesign --verify --deep --strict "StillView - Simple Image Viewer.app"
spctl --assess --verbose=4 "StillView - Simple Image Viewer.app"
```

### Contact Information

**Developer**: Vinny Carpenter
**Website**: https://vinny.dev
**Support**: https://github.com/vscarpenter/SimpleImageViewer/issues
**Setapp Portal**: https://developer.setapp.com

---

*Last Updated: 2025-10-02*
*App Version: 2.5.4*
*Document Version: 1.0*

#!/bin/bash

# Build script for App Store distribution
# This script builds the app for distribution and prepares it for notarization

set -e

# Configuration
PROJECT_NAME="Simple Image Viewer"
SCHEME="Simple Image Viewer"
CONFIGURATION="Release"
ARCHIVE_PATH="build/SimpleImageViewer.xcarchive"
EXPORT_PATH="build/export"

echo "🏗️  Building $PROJECT_NAME for distribution..."

# Check if Developer ID certificate is available
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "⚠️  Warning: No Developer ID Application certificate found."
    echo "   For development builds, the app will be signed with Apple Development certificate."
    echo "   For distribution, you'll need to install a Developer ID Application certificate."
    echo ""
fi

# Clean build directory
rm -rf build
mkdir -p build

# Archive the project
echo "📦 Creating archive..."
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    # Use Developer ID for distribution
    xcodebuild archive \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS" \
        CODE_SIGN_IDENTITY="Developer ID Application" \
        CODE_SIGN_STYLE=Manual \
        DEVELOPMENT_TEAM="52HVJ3VDSM"
else
    # Use automatic signing for development
    echo "ℹ️  Using automatic code signing for development build..."
    xcodebuild archive \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="52HVJ3VDSM"
fi

# Export for distribution
echo "📤 Exporting for distribution..."
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist Scripts/ExportOptions.plist
else
    # Create a development export options plist
    cat > Scripts/ExportOptions-Dev.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>52HVJ3VDSM</string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist Scripts/ExportOptions-Dev.plist
fi

echo "✅ Build complete! App exported to: $EXPORT_PATH"

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "📋 Next steps for distribution:"
    echo "   1. Notarize the app: xcrun notarytool submit '$EXPORT_PATH/$PROJECT_NAME.app' --keychain-profile 'notarytool-profile'"
    echo "   2. Staple the notarization: xcrun stapler staple '$EXPORT_PATH/$PROJECT_NAME.app'"
    echo "   3. Verify notarization: spctl -a -vvv -t install '$EXPORT_PATH/$PROJECT_NAME.app'"
else
    echo "📋 Development build complete:"
    echo "   - App is signed for development use"
    echo "   - To create a distribution build, install a Developer ID Application certificate"
    echo "   - Test the app: open '$EXPORT_PATH/$PROJECT_NAME.app'"
fi
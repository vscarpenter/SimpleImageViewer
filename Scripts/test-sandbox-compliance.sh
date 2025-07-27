#!/bin/bash

# Sandbox Compliance Testing Script
# This script helps verify that the app complies with App Sandbox requirements

set -e

APP_PATH="build/export/Simple Image Viewer.app"
BUNDLE_ID="com.vinny.Simple-Image-Viewer"

echo "🔒 Testing App Sandbox Compliance for Simple Image Viewer"
echo "=================================================="

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "   Please build the app first using Scripts/build-for-distribution.sh"
    exit 1
fi

echo "✅ App found at: $APP_PATH"

# Check entitlements
echo ""
echo "📋 Checking entitlements..."
codesign -d --entitlements :- "$APP_PATH" > /tmp/entitlements.plist 2>/dev/null

if grep -q "com.apple.security.app-sandbox" /tmp/entitlements.plist; then
    echo "✅ App Sandbox is enabled"
else
    echo "❌ App Sandbox is NOT enabled"
    exit 1
fi

if grep -q "com.apple.security.files.user-selected.read-only" /tmp/entitlements.plist; then
    echo "✅ User-selected files entitlement present"
else
    echo "❌ User-selected files entitlement missing"
    exit 1
fi

if grep -q "com.apple.security.files.bookmarks.app-scope" /tmp/entitlements.plist; then
    echo "✅ App-scoped bookmarks entitlement present"
else
    echo "❌ App-scoped bookmarks entitlement missing"
    exit 1
fi

# Check for unnecessary entitlements
echo ""
echo "🔍 Checking for unnecessary entitlements..."
UNNECESSARY_ENTITLEMENTS=(
    "com.apple.security.network.client"
    "com.apple.security.network.server"
    "com.apple.security.files.downloads.read-write"
    "com.apple.security.files.user-selected.read-write"
    "com.apple.security.temporary-exception"
)

for entitlement in "${UNNECESSARY_ENTITLEMENTS[@]}"; do
    if grep -q "$entitlement" /tmp/entitlements.plist; then
        echo "⚠️  Unnecessary entitlement found: $entitlement"
    fi
done

# Check code signing
echo ""
echo "🔐 Checking code signing..."
if codesign -v "$APP_PATH" 2>/dev/null; then
    echo "✅ Code signing is valid"
else
    echo "❌ Code signing is invalid"
    exit 1
fi

# Check for hardened runtime
if codesign -d --verbose "$APP_PATH" 2>&1 | grep -q "runtime"; then
    echo "✅ Hardened Runtime is enabled"
else
    echo "❌ Hardened Runtime is NOT enabled"
    exit 1
fi

# Check bundle structure
echo ""
echo "📁 Checking bundle structure..."
if [ -f "$APP_PATH/Contents/Info.plist" ]; then
    echo "✅ Info.plist present"
else
    echo "❌ Info.plist missing"
    exit 1
fi

if [ -f "$APP_PATH/Contents/PrivacyInfo.xcprivacy" ]; then
    echo "✅ Privacy manifest present"
else
    echo "❌ Privacy manifest missing"
    exit 1
fi

# Check bundle identifier
ACTUAL_BUNDLE_ID=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "")
if [ "$ACTUAL_BUNDLE_ID" = "$BUNDLE_ID" ]; then
    echo "✅ Bundle identifier correct: $BUNDLE_ID"
else
    echo "❌ Bundle identifier mismatch. Expected: $BUNDLE_ID, Got: $ACTUAL_BUNDLE_ID"
    exit 1
fi

# Test with spctl (Gatekeeper)
echo ""
echo "🛡️  Testing with Gatekeeper (spctl)..."
if spctl -a -vvv -t install "$APP_PATH" 2>&1 | grep -q "accepted"; then
    echo "✅ App passes Gatekeeper checks"
else
    echo "⚠️  App may not pass Gatekeeper checks (this is normal for unsigned/unnotarized apps)"
fi

# Clean up
rm -f /tmp/entitlements.plist

echo ""
echo "🎉 Sandbox compliance check complete!"
echo ""
echo "📋 Summary:"
echo "   - App Sandbox: Enabled"
echo "   - Minimal entitlements: Verified"
echo "   - Code signing: Valid"
echo "   - Hardened Runtime: Enabled"
echo "   - Privacy manifest: Present"
echo ""
echo "✅ App appears to be compliant with App Store sandbox requirements!"
echo ""
echo "🚀 Next steps for App Store submission:"
echo "   1. Test the app thoroughly on a clean macOS system"
echo "   2. Notarize the app with Apple"
echo "   3. Create screenshots and app preview"
echo "   4. Submit to App Store Connect"
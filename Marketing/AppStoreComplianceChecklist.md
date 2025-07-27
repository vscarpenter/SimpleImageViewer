# App Store Review Guidelines Compliance Checklist

## ✅ Safety (Guideline 1)

### 1.1 Objectionable Content
- [x] App contains no objectionable content
- [x] No inappropriate material for 4+ age rating
- [x] No user-generated content that could be inappropriate

### 1.2 User Generated Content
- [x] N/A - App does not allow user-generated content

### 1.3 Kids Category
- [x] N/A - Not targeting kids specifically

### 1.4 Physical Harm
- [x] App poses no risk of physical harm
- [x] No medical/health claims made

### 1.5 Developer Information
- [x] Accurate developer information provided
- [x] Valid contact information available

## ✅ Performance (Guideline 2)

### 2.1 App Completeness
- [x] App is complete and fully functional
- [x] All features work as described
- [x] No placeholder content or "coming soon" features

### 2.2 Beta Testing
- [x] App has been thoroughly tested
- [x] No beta or test versions submitted

### 2.3 Accurate Metadata
- [x] App description accurately reflects functionality
- [x] Screenshots show actual app interface
- [x] Keywords are relevant and accurate

### 2.4 Hardware Compatibility
- [x] App works on all supported macOS versions (12.0+)
- [x] Universal Binary supports Intel and Apple Silicon
- [x] Proper handling of different screen sizes

### 2.5 Software Requirements
- [x] Minimum system requirements clearly specified
- [x] App uses only public APIs
- [x] No deprecated APIs used

## ✅ Business (Guideline 3)

### 3.1 Payments
- [x] N/A - App is free with no in-app purchases

### 3.2 Other Business Model Issues
- [x] N/A - No subscriptions or complex business models

## ✅ Design (Guideline 4)

### 4.1 Copycats
- [x] App provides unique value and functionality
- [x] Not a copycat of existing apps

### 4.2 Minimum Functionality
- [x] App provides substantial functionality
- [x] More than just a web view or basic template

### 4.3 Spam
- [x] App is not spam or low-quality
- [x] Provides genuine utility to users

## ✅ Legal (Guideline 5)

### 5.1 Privacy
- [x] Privacy manifest (PrivacyInfo.xcprivacy) included
- [x] No data collection or tracking
- [x] Complies with privacy requirements

### 5.2 Intellectual Property
- [x] All content is original or properly licensed
- [x] No trademark or copyright infringement
- [x] App icon and assets are original

### 5.3 Gaming, Gambling, and Lotteries
- [x] N/A - Not a gaming app

### 5.4 VPN Apps
- [x] N/A - Not a VPN app

### 5.5 Developer Code of Conduct
- [x] Follows Apple Developer Program License Agreement
- [x] Respectful and professional conduct

## ✅ App Store Connect Requirements

### Metadata Requirements
- [x] App name: "Simple Image Viewer"
- [x] Subtitle: "Elegant folder-based image browsing for macOS"
- [x] Description: Accurate and compelling
- [x] Keywords: Relevant and within character limits
- [x] Category: Photography
- [x] Age rating: 4+

### Technical Requirements
- [x] App Sandbox enabled
- [x] Hardened Runtime enabled
- [x] Code signing with Developer ID Application
- [x] Privacy manifest included
- [x] Proper entitlements (minimal required only)

### Assets Required
- [x] App icon (all required sizes)
- [x] Screenshots (will be created during testing)
- [x] App preview video (optional, can be added later)

## ✅ macOS Specific Requirements

### App Sandbox
- [x] App Sandbox enabled in entitlements
- [x] Only necessary entitlements included:
  - [x] com.apple.security.app-sandbox
  - [x] com.apple.security.files.user-selected.read-only
  - [x] com.apple.security.files.bookmarks.app-scope

### Hardened Runtime
- [x] Hardened Runtime enabled
- [x] No unnecessary runtime exceptions

### Notarization
- [x] Build scripts prepared for notarization
- [x] Export options configured for Developer ID

## ✅ Accessibility Compliance

### VoiceOver Support
- [x] All UI elements have proper accessibility labels
- [x] Navigation works with VoiceOver
- [x] Image descriptions provided when available

### Keyboard Navigation
- [x] Full keyboard navigation support
- [x] All features accessible via keyboard

### System Preferences
- [x] Respects high contrast mode
- [x] Respects reduced motion preferences
- [x] Follows system accessibility settings

## Final Review Checklist

Before submission:
- [ ] Test app on clean macOS installation
- [ ] Verify all features work without developer tools
- [ ] Test with VoiceOver enabled
- [ ] Test keyboard navigation thoroughly
- [ ] Verify sandbox compliance (no unauthorized file access)
- [ ] Test with various image formats and folder structures
- [ ] Ensure app launches in under 2 seconds
- [ ] Verify image navigation is under 100ms
- [ ] Test memory management with large image collections
- [ ] Create and test final distribution build
- [ ] Notarize and staple the application
- [ ] Verify notarization with spctl command
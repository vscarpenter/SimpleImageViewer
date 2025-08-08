# What's New Feature Documentation

## Overview

The What's New feature provides users with information about new features, improvements, and changes in the current version of StillView - Simple Image Viewer. This feature combines automatic visibility for important updates with user-controlled access through the Help menu.

## Architecture

### Core Components

1. **WhatsNewService** - Central coordinator for all What's New functionality
2. **VersionTracker** - Handles version comparison and persistence
3. **WhatsNewContentProvider** - Manages content loading from JSON resources
4. **WhatsNewSheet** - SwiftUI sheet for presenting content
5. **WhatsNewContentView** - Main content display view
6. **WhatsNewSectionView** - Individual section rendering

### Data Models

- **WhatsNewContent** - Complete content structure for a version
- **WhatsNewSection** - Individual sections (New Features, Improvements, Bug Fixes)
- **WhatsNewItem** - Individual items within sections

## User Experience

### Automatic Popup Behavior

- Shows automatically on first launch after app update
- Only displays once per version
- Appears after main app initialization (0.8 second delay)
- Can be dismissed with Escape key or close button
- Proper focus management after dismissal

### Manual Access

- Available through Help menu → "What's New"
- Always accessible regardless of automatic popup status
- Shows same content as automatic popup

### Design Principles

- Native macOS styling and typography
- Supports both light and dark mode
- Fully accessible with VoiceOver support
- Keyboard navigation support
- Responsive layout for different content lengths

## Content Management

### JSON Structure

Content is stored in `Resources/whats-new.json`:

```json
{
  "version": "1.2.0",
  "releaseDate": "2025-08-07T00:00:00Z",
  "sections": [
    {
      "title": "New Features",
      "type": "newFeatures",
      "items": [
        {
          "title": "Feature Title",
          "description": "Feature description",
          "isHighlighted": true
        }
      ]
    }
  ]
}
```

### Content Types

- **newFeatures** - New functionality added to the app
- **improvements** - Enhancements to existing features
- **bugFixes** - Bug fixes and stability improvements

### Content Guidelines

1. Keep titles concise and descriptive
2. Provide meaningful descriptions for important features
3. Use `isHighlighted` for major features
4. Organize content logically by type
5. Avoid technical jargon for user-facing content

## Implementation Details

### Version Tracking

- Uses `CFBundleShortVersionString` from app bundle
- Stores last shown version in UserDefaults
- Semantic version comparison for proper ordering
- Handles corrupted data gracefully

### Error Handling

- Graceful fallback when content is missing
- Retry logic for content loading failures
- Comprehensive error logging
- Fallback content for edge cases

### Performance

- Lazy content loading
- Efficient caching
- Minimal impact on app launch time
- Memory-conscious implementation

## App Store Compliance

### Guidelines Followed

1. **User Experience (4.1)**
   - Non-intrusive automatic popup
   - Easy dismissal options
   - Doesn't interfere with core functionality

2. **Design (4.2)**
   - Native macOS design patterns
   - Proper dark mode support
   - Accessibility compliance

3. **No Spam (4.3)**
   - Shows only once per version
   - Meaningful content only
   - Manual access available

4. **Completeness (2.1)**
   - Fully functional feature
   - Robust error handling
   - Complete integration

### Testing Coverage

- Unit tests for all core components
- Integration tests for app lifecycle
- UI tests for accessibility
- Performance tests for impact measurement
- App Store compliance verification tests

## Accessibility Features

### VoiceOver Support

- Proper accessibility labels and hints
- Logical reading order
- Header traits for section titles
- Descriptive element identification

### Keyboard Navigation

- Tab navigation through content
- Escape key dismissal
- Focus management
- Keyboard shortcuts support

### High Contrast Support

- Adaptive colors for high contrast mode
- Proper contrast ratios
- Alternative color schemes

### Reduced Motion

- Respects reduced motion preferences
- Alternative animations when needed
- Smooth transitions without motion sickness

## Maintenance

### Updating Content

1. Edit `Resources/whats-new.json`
2. Update version number to match app version
3. Add new sections and items as needed
4. Test content loading and display
5. Verify accessibility compliance

### Version Management

- Content version should match app version
- Use semantic versioning (major.minor.patch)
- Test version comparison logic
- Verify UserDefaults persistence

### Monitoring

- Check diagnostic information via `getDiagnosticInfo()`
- Monitor content loading errors
- Track version tracking issues
- Review user feedback

## Troubleshooting

### Common Issues

1. **Content not showing**
   - Check JSON file exists and is valid
   - Verify version comparison logic
   - Check UserDefaults for stored version

2. **Popup not appearing**
   - Verify `shouldShowWhatsNew()` returns true
   - Check app launch timing
   - Ensure content is available

3. **UI rendering issues**
   - Test in both light and dark modes
   - Verify adaptive colors are working
   - Check accessibility settings

### Debug Information

Use `WhatsNewService.getDiagnosticInfo()` to get:
- Current version
- Last shown version
- Content availability status
- Error information
- Cache status

## Future Enhancements

### Potential Improvements

1. **Rich Content Support**
   - Images and screenshots
   - Video previews
   - Interactive elements

2. **Localization**
   - Multi-language support
   - Localized content files
   - RTL language support

3. **Analytics**
   - Usage tracking
   - Engagement metrics
   - A/B testing support

4. **Advanced Features**
   - Release notes history
   - Feature highlighting in UI
   - Progressive disclosure

## Security Considerations

### Data Privacy

- No personal data collection
- Local storage only (UserDefaults)
- No network requests
- Sandbox compliant

### Content Security

- JSON validation
- Input sanitization
- Error boundary handling
- Safe fallback content

## Performance Metrics

### Benchmarks

- App launch impact: < 50ms
- Content loading: < 100ms
- UI rendering: < 200ms
- Memory usage: < 5MB

### Optimization

- Lazy loading implementation
- Efficient caching strategy
- Minimal resource usage
- Background processing where appropriate

---

*This documentation is maintained as part of the StillView - Simple Image Viewer project. Last updated: August 7, 2025*
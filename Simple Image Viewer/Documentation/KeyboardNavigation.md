# Keyboard Navigation System

## Overview

The Simple Image Viewer implements a comprehensive keyboard navigation system that allows users to browse images and control the application entirely through keyboard shortcuts. This system is designed to be intuitive and follows common conventions used in image viewing applications.

## Architecture

### KeyboardHandler Class

The `KeyboardHandler` class is the central component that manages all keyboard input:

- **Purpose**: Translates keyboard events into application actions
- **Integration**: Works with `ImageViewerViewModel` to execute navigation and zoom commands
- **Platform**: Uses AppKit's `NSEvent` system for reliable key detection

### Key Components

1. **KeyboardHandler**: Main service class that processes keyboard events
2. **KeyCaptureView**: Custom NSView for reliable key event capture
3. **KeyCaptureViewRepresentable**: SwiftUI wrapper for the NSView
4. **ContentView Integration**: Main UI integration point

## Supported Keyboard Shortcuts

### Navigation
- **← / →**: Navigate between images (previous/next)
- **Spacebar**: Next image (common convention)
- **Page Up/Down**: Navigate between images (alternative)
- **Home**: Go to first image in folder
- **End**: Go to last image in folder

### Zoom Controls
- **+ / =**: Zoom in
- **-**: Zoom out
- **0**: Fit image to window
- **1**: Actual size (100% zoom)

### View Controls
- **F / Enter**: Toggle fullscreen mode
- **Escape**: Exit fullscreen mode

## Implementation Details

### Event Handling Flow

1. User presses a key
2. `KeyCaptureView` receives the `NSEvent`
3. Event is passed to `KeyboardHandler.handleKeyPress()`
4. Handler identifies the key and calls appropriate `ImageViewerViewModel` method
5. ViewModel updates the UI state
6. SwiftUI automatically updates the interface

### Key Code Mapping

The system uses both key codes and character recognition:

```swift
// Special keys (by key code)
case 123: // Left arrow
case 124: // Right arrow
case 115: // Home
case 119: // End
case 116: // Page Up
case 121: // Page Down
case 53:  // Escape
case 36:  // Enter/Return
case 49:  // Spacebar

// Character keys (by character)
case "f": // Fullscreen toggle
case "+", "=": // Zoom in
case "-": // Zoom out
case "0": // Fit to window
case "1": // Actual size
```

### Focus Management

The system ensures proper keyboard focus through:

1. **KeyCaptureView**: Custom NSView that accepts first responder status
2. **Focus Maintenance**: Automatically maintains focus when needed
3. **Hit Testing**: Configured to not interfere with mouse interactions

## Integration with SwiftUI

### ContentView Integration

```swift
.background(
    KeyCaptureViewRepresentable { event in
        return keyboardHandler.handleKeyPress(event)
    }
    .allowsHitTesting(false)
)
```

### ViewModel Connection

```swift
private func setupKeyboardHandling() {
    keyboardHandler.setImageViewerViewModel(imageViewerViewModel)
}
```

## Testing

The keyboard navigation system includes comprehensive unit tests:

### Test Coverage
- Individual key press handling
- Navigation commands (next, previous, first, last)
- Zoom commands (in, out, fit, actual size)
- Fullscreen toggle and escape handling
- Edge cases (no view model, unknown keys)
- Integration with real view model

### Mock Objects
- `MockImageViewerViewModel`: Tracks method calls for verification
- Test helper methods for creating `NSEvent` objects

## User Experience Considerations

### Discoverability
- Keyboard shortcuts are documented in the app's Help menu
- Command+? shows a shortcuts dialog
- Shortcuts follow common conventions

### Responsiveness
- All keyboard actions execute immediately
- No delays or animation blocking
- Smooth transitions between images

### Accessibility
- Works with VoiceOver and other assistive technologies
- Follows macOS accessibility guidelines
- Keyboard navigation covers all functionality

## Performance

### Efficiency
- Direct event handling without intermediate layers
- Minimal processing overhead
- No memory leaks or retain cycles

### Resource Usage
- Lightweight key capture mechanism
- Efficient event filtering
- Proper cleanup on view destruction

## Future Enhancements

Potential improvements to consider:

1. **Customizable Shortcuts**: Allow users to customize key bindings
2. **Additional Navigation**: Support for jumping by percentage (e.g., Ctrl+1-9)
3. **Modifier Keys**: Support for Shift/Cmd combinations
4. **Context Sensitivity**: Different shortcuts in different modes

## Troubleshooting

### Common Issues

1. **Keys Not Responding**: Ensure the main view has focus
2. **Partial Functionality**: Check that ImageViewerViewModel is properly connected
3. **Conflicts**: Verify no other components are capturing the same keys

### Debug Information

The system provides debug capabilities through:
- Return values from `handleKeyPress()` indicate if events were handled
- Mock objects in tests track all method calls
- Formatted shortcuts list for documentation
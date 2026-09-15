# Keyboard Navigation

StillView’s image commands use built-in bindings. Preferences → Shortcuts displays a searchable, read-only reference from `KeyboardHandler.getKeyboardShortcuts()`.

## Focus and scope

Image commands apply while an image collection is visible and the viewer owns keyboard focus. They do not target a hidden collection from the welcome screen. Text fields, focused controls, dialogs, and other windows retain their normal key behavior. App commands such as Open Folder (⌘O), Preferences (⌘,), and Help (⌘?) remain available through the menu bar.

| Key | Action |
|---|---|
| ← / → | Previous / next image |
| Page Up / Page Down | Previous / next image |
| Home / End | First / last image |
| Space | Stop an active slideshow; otherwise next image |
| + / = | Zoom in |
| - | Zoom out |
| 0 | Fit image to window |
| 1 | Actual size |
| F | Toggle fullscreen |
| Enter | Open the selected image in Single from Grid; otherwise toggle fullscreen |
| Escape | Exit fullscreen, or return from Grid/Strip to Single |
| I | Toggle the Info and Insights inspector |
| ⌘I | Open the inspector on Insights |
| S | Start / stop slideshow |
| T | Toggle Strip view |
| G | Toggle Grid view |
| B | Return to folder selection |
| Delete / Backspace | Confirm moving the current image to Trash |

Escape never returns to folder selection. Use B with the viewer focused or File → Back to Folder Selection. Slideshows always repeat after the last image; Space stops them, and S starts them again.

## Implementation

`ContentView` owns collection visibility and enables viewer keyboard capture only for the visible viewer. `KeyCaptureViewRepresentable` provides AppKit event capture and responder checks. `KeyboardHandler` maps eligible events to `ImageViewerViewModel` actions. Application commands belong to the SwiftUI menu system.

The displayed built-in shortcut reference and event dispatcher live in `KeyboardHandler.swift`. Changing a binding requires updating its dispatch and its reference together. Saved custom shortcut definitions are not an active viewer feature.

## Verification

Check commands with the viewer focused in Single, Strip, and Grid. Then check that the same keys preserve native behavior in search fields, sliders, buttons, modal dialogs, Preferences, and Help. From the welcome screen, Delete must not act on the previous collection. Test Open Folder from both welcome and viewer, including cancellation.

`KeyboardHandlerTests` and viewer interaction tests cover dispatch and focus boundaries. A running-app check is still required for AppKit responder behavior and menu interaction.

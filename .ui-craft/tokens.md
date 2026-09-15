# Native Settings tokens

These decisions are scoped to Settings; the viewer retains its existing design system.

| Role | Implementation |
| --- | --- |
| Window and navigation | AppKit preference toolbar; system-managed selection and materials |
| Forms | SwiftUI grouped Form and Section, standard Switch and Stepper |
| Foreground | SwiftUI primary and secondary semantic styles |
| Background | Native grouped-form surface; NSColor.windowBackgroundColor for Shortcuts |
| Accent | System control tint; no custom accent overlay |
| Typography | System body and native section/footer hierarchy; monospaced shortcut keys and duration digits |
| Search and focus | NSSearchField, native focus ring, clear button, Escape handling |
| Spacing | 8 pt search insets, 16 pt sibling spacing, 20 pt Shortcuts margins |
| Window size | 560 pt content width; General 320, Intelligence 360, Shortcuts 440 pt content height |
| Motion | No custom entrance, slide, or spring transitions |
| Dark and accessibility modes | Inherit macOS appearance; no app-specific override or custom translucency preference |

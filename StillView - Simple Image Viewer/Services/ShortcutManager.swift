import SwiftUI
import Combine
import Carbon

/// Service for managing keyboard shortcuts and their recording
class ShortcutManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently recorded shortcut during recording session
    @Published var recordedShortcut: KeyboardShortcut?
    
    /// Whether a recording session is active
    @Published var isRecording: Bool = false
    
    /// Current recording session ID
    @Published var recordingSessionId: String?
    
    // MARK: - Private Properties
    
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var recordingCompletion: ((KeyboardShortcut?) -> Void)?
    
    // MARK: - Singleton
    
    static let shared = ShortcutManager()
    
    private init() {
        setupEventMonitoring()
    }
    
    deinit {
        stopRecording()
    }
    
    // MARK: - Public Methods
    
    /// Start recording a keyboard shortcut
    /// - Parameters:
    ///   - sessionId: Unique identifier for this recording session
    ///   - completion: Callback when recording completes
    func startRecording(sessionId: String, completion: @escaping (KeyboardShortcut?) -> Void) {
        // Stop any existing recording
        stopRecording()
        
        recordingSessionId = sessionId
        recordingCompletion = completion
        isRecording = true
        recordedShortcut = nil
        
        // Start monitoring key events
        startEventMonitoring()
    }
    
    /// Stop the current recording session
    func stopRecording() {
        isRecording = false
        recordingSessionId = nil
        recordedShortcut = nil
        
        stopEventMonitoring()
        
        if let completion = recordingCompletion {
            recordingCompletion = nil
            completion(nil)
        }
    }
    
    /// Complete the recording with the current shortcut
    func completeRecording() {
        guard isRecording, let shortcut = recordedShortcut else { return }
        
        let completion = recordingCompletion
        
        isRecording = false
        recordingSessionId = nil
        recordingCompletion = nil
        
        stopEventMonitoring()
        
        completion?(shortcut)
    }
    
    /// Cancel the current recording session
    func cancelRecording() {
        stopRecording()
    }
    
    /// Validate a keyboard shortcut for conflicts and usability
    /// - Parameters:
    ///   - shortcut: The shortcut to validate
    ///   - excludingId: ID to exclude from conflict checking
    ///   - shortcuts: Current shortcuts dictionary
    /// - Returns: Validation result
    func validateShortcut(
        _ shortcut: KeyboardShortcut,
        excludingId: String? = nil,
        against shortcuts: [String: ShortcutDefinition] = [:]
    ) -> ValidationResult {
        
        // Check basic validity
        guard shortcut.isValid else {
            return .error(
                "Invalid shortcut combination",
                suggestion: "Add at least one modifier key (⌘, ⌥, ⇧, ⌃) for letter keys"
            )
        }
        
        // Check for system conflicts
        if isSystemShortcut(shortcut) {
            return .error(
                "This shortcut conflicts with a system shortcut",
                suggestion: "Choose a different key combination"
            )
        }
        
        // Check for conflicts with other app shortcuts
        for (id, otherShortcut) in shortcuts {
            if let excludingId = excludingId, id == excludingId { continue }
            
            if otherShortcut.currentShortcut == shortcut {
                return .error(
                    "This shortcut is already used by '\(otherShortcut.name)'",
                    suggestion: "Choose a different key combination or reset the conflicting shortcut"
                )
            }
        }
        
        // Check for potential usability issues
        if shortcut.modifiers.isEmpty && shortcut.key.count == 1 {
            return .warning(
                "Single key shortcuts may interfere with text input",
                suggestion: "Consider adding a modifier key for better usability"
            )
        }
        
        // Check for accessibility concerns
        if shortcut.modifiers.contains(.control) && shortcut.modifiers.contains(.option) {
            return .warning(
                "Control+Option combinations may conflict with accessibility features",
                suggestion: "Consider using Command or Shift instead"
            )
        }
        
        return .success(message: "Shortcut is valid and available")
    }
    
    /// Check if a shortcut conflicts with system shortcuts
    /// - Parameter shortcut: The shortcut to check
    /// - Returns: True if it conflicts with system shortcuts
    func isSystemShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        return KeyboardShortcut.systemShortcuts.contains(shortcut) || 
               isCommonSystemShortcut(shortcut)
    }
    
    /// Get suggestions for alternative shortcuts
    /// - Parameter baseShortcut: The shortcut to find alternatives for
    /// - Returns: Array of suggested alternative shortcuts
    func suggestAlternatives(for baseShortcut: KeyboardShortcut) -> [KeyboardShortcut] {
        var suggestions: [KeyboardShortcut] = []
        
        // Try different modifier combinations
        let modifierCombinations: [ModifierFlags] = [
            [.command, .shift],
            [.command, .option],
            [.option, .shift],
            [.command, .control],
            [.command, .shift, .option]
        ]
        
        for modifiers in modifierCombinations {
            let suggestion = KeyboardShortcut(key: baseShortcut.key, modifiers: modifiers)
            if !isSystemShortcut(suggestion) {
                suggestions.append(suggestion)
            }
        }
        
        // Try similar keys
        let similarKeys = getSimilarKeys(for: baseShortcut.key)
        for key in similarKeys {
            let suggestion = KeyboardShortcut(key: key, modifiers: baseShortcut.modifiers)
            if !isSystemShortcut(suggestion) {
                suggestions.append(suggestion)
            }
        }
        
        return Array(suggestions.prefix(5)) // Return up to 5 suggestions
    }
    
    // MARK: - Private Methods
    
    private func setupEventMonitoring() {
        // Initial setup - actual event monitoring will be started when recording begins
    }
    
    private func startEventMonitoring() {
        guard eventMonitor == nil else { return }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil // Consume the event during recording
        }
    }
    
    private func stopEventMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }
        
        let modifiers = ModifierFlags(nsEventModifiers: event.modifierFlags)
        
        if event.type == .keyDown {
            // Handle key press
            let key = keyStringFromEvent(event)
            let shortcut = KeyboardShortcut(key: key, modifiers: modifiers)
            
            // Update recorded shortcut
            DispatchQueue.main.async { [weak self] in
                self?.recordedShortcut = shortcut
            }
            
        } else if event.type == .flagsChanged {
            // Handle modifier changes
            if !modifiers.isEmpty {
                // Show current modifiers
                let shortcut = KeyboardShortcut(key: "", modifiers: modifiers)
                DispatchQueue.main.async { [weak self] in
                    self?.recordedShortcut = shortcut
                }
            }
        }
    }
    
    private static let keyCodeMapping: [UInt16: String] = [
        // Letters
        0x00: "a", 0x0B: "b", 0x08: "c", 0x02: "d", 0x0E: "e", 0x03: "f",
        0x05: "g", 0x04: "h", 0x22: "i", 0x26: "j", 0x28: "k", 0x25: "l",
        0x2E: "m", 0x2D: "n", 0x1F: "o", 0x23: "p", 0x0C: "q", 0x0F: "r",
        0x01: "s", 0x11: "t", 0x20: "u", 0x09: "v", 0x0D: "w", 0x07: "x",
        0x10: "y", 0x06: "z",

        // Numbers
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
        0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9",

        // Special keys
        0x31: "space", 0x24: "return", 0x30: "tab", 0x33: "delete", 0x35: "escape",
        0x7B: "arrowleft", 0x7C: "arrowright", 0x7D: "arrowdown", 0x7E: "arrowup",
        0x73: "home", 0x77: "end", 0x74: "pageup", 0x79: "pagedown",

        // Symbols
        0x18: "=", 0x1B: "-", 0x21: "[", 0x1E: "]", 0x2A: "\\",
        0x29: ";", 0x27: "'", 0x2B: ",", 0x2F: ".", 0x2C: "/",

        // Function keys
        0x7A: "f1", 0x78: "f2", 0x63: "f3", 0x76: "f4", 0x60: "f5", 0x61: "f6",
        0x62: "f7", 0x64: "f8", 0x65: "f9", 0x6D: "f10", 0x67: "f11", 0x6F: "f12"
    ]

    private func keyStringFromEvent(_ event: NSEvent) -> String {
        let keyCode = event.keyCode

        // Use dictionary lookup for known key codes
        if let keyString = ShortcutManager.keyCodeMapping[keyCode] {
            return keyString
        }

        // Fallback to character representation
        if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            return characters.lowercased()
        }

        return "unknown"
    }
    
    private func isCommonSystemShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        // Additional system shortcuts not in the static list
        let commonSystemShortcuts: Set<KeyboardShortcut> = [
            KeyboardShortcut(key: "space", modifiers: [.command]), // Spotlight
            KeyboardShortcut(key: "tab", modifiers: [.command]), // App switcher
            KeyboardShortcut(key: "q", modifiers: [.command]), // Quit
            KeyboardShortcut(key: "w", modifiers: [.command]), // Close window
            KeyboardShortcut(key: "m", modifiers: [.command]), // Minimize
            KeyboardShortcut(key: "h", modifiers: [.command]), // Hide
            KeyboardShortcut(key: ",", modifiers: [.command]), // Preferences
        ]
        
        return commonSystemShortcuts.contains(shortcut)
    }
    
    private func getSimilarKeys(for key: String) -> [String] {
        // Return keys that are similar or nearby on the keyboard
        let keyGroups: [String: [String]] = [
            "a": ["s", "q", "w"],
            "s": ["a", "d", "w", "e"],
            "d": ["s", "f", "e", "r"],
            "f": ["d", "g", "r", "t"],
            "g": ["f", "h", "t", "y"],
            "h": ["g", "j", "y", "u"],
            "j": ["h", "k", "u", "i"],
            "k": ["j", "l", "i", "o"],
            "l": ["k", "o", "p"],
            "q": ["w", "a"],
            "w": ["q", "e", "a", "s"],
            "e": ["w", "r", "s", "d"],
            "r": ["e", "t", "d", "f"],
            "t": ["r", "y", "f", "g"],
            "y": ["t", "u", "g", "h"],
            "u": ["y", "i", "h", "j"],
            "i": ["u", "o", "j", "k"],
            "o": ["i", "p", "k", "l"],
            "p": ["o", "l"]
        ]
        
        return keyGroups[key.lowercased()] ?? []
    }
}

// MARK: - SwiftUI Integration

/// Environment key for ShortcutManager
struct ShortcutManagerKey: EnvironmentKey {
    static let defaultValue = ShortcutManager.shared
}

extension EnvironmentValues {
    var shortcutManager: ShortcutManager {
        get { self[ShortcutManagerKey.self] }
        set { self[ShortcutManagerKey.self] = newValue }
    }
}

// MARK: - View Modifier for Shortcut Recording

struct ShortcutRecordingModifier: ViewModifier {
    let sessionId: String
    let onRecorded: (KeyboardShortcut?) -> Void
    
    @Environment(\.shortcutManager) private var shortcutManager
    @State private var isActive = false
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if !isActive {
                    isActive = true
                    shortcutManager.startRecording(sessionId: sessionId) { shortcut in
                        isActive = false
                        onRecorded(shortcut)
                    }
                }
            }
            .onDisappear {
                if isActive {
                    shortcutManager.stopRecording()
                    isActive = false
                }
            }
    }
}

extension View {
    /// Add shortcut recording capability to a view
    func shortcutRecording(sessionId: String, onRecorded: @escaping (KeyboardShortcut?) -> Void) -> some View {
        self.modifier(ShortcutRecordingModifier(sessionId: sessionId, onRecorded: onRecorded))
    }
}
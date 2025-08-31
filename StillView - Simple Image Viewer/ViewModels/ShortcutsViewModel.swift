import SwiftUI
import Combine

/// ViewModel for managing keyboard shortcuts preferences
@MainActor
class ShortcutsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All available shortcuts organized by category
    @Published var shortcutCategories: [ShortcutCategory_Group] = []
    
    /// Search text for filtering shortcuts
    @Published var searchText: String = ""
    
    /// Whether there are any custom shortcuts
    @Published var hasCustomShortcuts: Bool = false
    
    /// Validation results for shortcut conflicts
    @Published var validationResults: [String: ValidationResult] = [:]
    
    /// Whether changes have been made
    @Published var hasUnsavedChanges: Bool = false
    
    // MARK: - Private Properties
    
    private var shortcuts: [String: ShortcutDefinition] = [:]
    private let shortcutManager = ShortcutManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var initialShortcuts: [String: ShortcutDefinition] = [:]
    
    // MARK: - Computed Properties
    
    /// Filtered shortcuts based on search text
    var filteredShortcuts: [ShortcutCategory_Group] {
        if searchText.isEmpty {
            return shortcutCategories
        }
        
        let filtered = shortcutCategories.compactMap { category in
            let matchingShortcuts = category.shortcuts.filter { shortcut in
                shortcut.name.localizedCaseInsensitiveContains(searchText) ||
                shortcut.description.localizedCaseInsensitiveContains(searchText) ||
                shortcut.currentShortcut.displayString.localizedCaseInsensitiveContains(searchText)
            }
            
            return matchingShortcuts.isEmpty ? nil : ShortcutCategory_Group(
                category: category.category,
                shortcuts: matchingShortcuts
            )
        }
        
        return filtered
    }
    
    // MARK: - Initialization
    
    init() {
        loadShortcuts()
        setupBindings()
        updateCategories()
        updateCustomShortcutsFlag()
        storeInitialState()
    }
    
    // MARK: - Public Methods
    
    /// Update a keyboard shortcut
    /// - Parameters:
    ///   - shortcutId: ID of the shortcut to update
    ///   - newShortcut: New keyboard shortcut
    func updateShortcut(_ shortcutId: String, to newShortcut: KeyboardShortcut) {
        guard var shortcut = shortcuts[shortcutId], shortcut.isCustomizable else { return }
        
        // Validate the new shortcut
        let validationResult = shortcutManager.validateShortcut(newShortcut, excludingId: shortcutId, against: shortcuts)
        validationResults[shortcutId] = validationResult
        
        if validationResult.isValid {
            shortcut.updateShortcut(newShortcut)
            shortcuts[shortcutId] = shortcut
            
            saveShortcuts()
            updateCategories()
            updateCustomShortcutsFlag()
            checkForUnsavedChanges()
        }
    }
    
    /// Reset a shortcut to its default value
    /// - Parameter shortcutId: ID of the shortcut to reset
    func resetShortcut(_ shortcutId: String) {
        guard var shortcut = shortcuts[shortcutId], shortcut.isCustomizable else { return }
        
        shortcut.resetToDefault()
        shortcuts[shortcutId] = shortcut
        validationResults.removeValue(forKey: shortcutId)
        
        saveShortcuts()
        updateCategories()
        updateCustomShortcutsFlag()
        checkForUnsavedChanges()
    }
    
    /// Reset all shortcuts to their default values
    func resetAllShortcuts() {
        for (id, var shortcut) in shortcuts {
            if shortcut.isCustomizable {
                shortcut.resetToDefault()
                shortcuts[id] = shortcut
            }
        }
        
        validationResults.removeAll()
        saveShortcuts()
        updateCategories()
        updateCustomShortcutsFlag()
        checkForUnsavedChanges()
    }
    
    /// Get validation result for a specific shortcut
    /// - Parameter shortcutId: ID of the shortcut
    /// - Returns: Validation result if available
    func getValidationResult(for shortcutId: String) -> ValidationResult? {
        return validationResults[shortcutId]
    }
    
    /// Check if a shortcut has conflicts
    /// - Parameter shortcutId: ID of the shortcut to check
    /// - Returns: True if the shortcut has conflicts
    func hasConflicts(_ shortcutId: String) -> Bool {
        guard let result = validationResults[shortcutId] else { return false }
        return !result.isValid
    }
    
    /// Get shortcut by ID
    /// - Parameter shortcutId: ID of the shortcut
    /// - Returns: Shortcut definition if found
    func getShortcut(_ shortcutId: String) -> ShortcutDefinition? {
        return shortcuts[shortcutId]
    }
    
    /// Export shortcuts to a dictionary for backup
    /// - Returns: Dictionary representation of all shortcuts
    func exportShortcuts() -> [String: Any] {
        var exported: [String: Any] = [:]
        
        for (id, shortcut) in shortcuts {
            if shortcut.isModified {
                exported[id] = [
                    "key": shortcut.currentShortcut.key,
                    "modifiers": shortcut.currentShortcut.modifiers.rawValue
                ]
            }
        }
        
        return exported
    }
    
    /// Import shortcuts from a dictionary
    /// - Parameter data: Dictionary containing shortcut data
    func importShortcuts(from data: [String: Any]) {
        for (id, value) in data {
            guard let shortcutData = value as? [String: Any],
                  let key = shortcutData["key"] as? String,
                  let modifiersRaw = shortcutData["modifiers"] as? Int,
                  var shortcut = shortcuts[id] else { continue }
            
            let modifiers = ModifierFlags(rawValue: modifiersRaw)
            let newShortcut = KeyboardShortcut(key: key, modifiers: modifiers)
            
            // Validate before importing
            let validationResult = shortcutManager.validateShortcut(newShortcut, excludingId: id, against: shortcuts)
            if validationResult.isValid {
                shortcut.updateShortcut(newShortcut)
                shortcuts[id] = shortcut
            }
        }
        
        saveShortcuts()
        updateCategories()
        updateCustomShortcutsFlag()
        checkForUnsavedChanges()
    }
    
    // MARK: - Private Methods
    
    private func loadShortcuts() {
        // Start with default shortcuts
        for shortcut in ShortcutDefinition.defaultShortcuts {
            shortcuts[shortcut.id] = shortcut
        }
        
        // Load customizations from UserDefaults
        loadCustomShortcuts()
    }
    
    private func loadCustomShortcuts() {
        let userDefaults = UserDefaults.standard
        
        for (id, var shortcut) in shortcuts {
            if let customData = userDefaults.dictionary(forKey: "Shortcut_\(id)"),
               let key = customData["key"] as? String,
               let modifiersRaw = customData["modifiers"] as? Int {
                
                let modifiers = ModifierFlags(rawValue: modifiersRaw)
                let customShortcut = KeyboardShortcut(key: key, modifiers: modifiers)
                shortcut.updateShortcut(customShortcut)
                shortcuts[id] = shortcut
            }
        }
    }
    
    private func saveShortcuts() {
        let userDefaults = UserDefaults.standard
        
        for (id, shortcut) in shortcuts {
            if shortcut.isModified {
                let data: [String: Any] = [
                    "key": shortcut.currentShortcut.key,
                    "modifiers": shortcut.currentShortcut.modifiers.rawValue
                ]
                userDefaults.set(data, forKey: "Shortcut_\(id)")
            } else {
                userDefaults.removeObject(forKey: "Shortcut_\(id)")
            }
        }
    }
    
    private func updateCategories() {
        let groupedShortcuts = Dictionary(grouping: shortcuts.values) { $0.category }
        
        shortcutCategories = ShortcutCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category in
                guard let categoryShortcuts = groupedShortcuts[category] else { return nil }
                
                let sortedShortcuts = categoryShortcuts.sorted { $0.name < $1.name }
                return ShortcutCategory_Group(category: category, shortcuts: sortedShortcuts)
            }
    }
    
    private func updateCustomShortcutsFlag() {
        hasCustomShortcuts = shortcuts.values.contains { $0.isModified }
    }
    
    private func setupBindings() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                // Search filtering is handled by computed property
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func storeInitialState() {
        initialShortcuts = shortcuts
    }
    
    private func checkForUnsavedChanges() {
        hasUnsavedChanges = shortcuts != initialShortcuts
    }
}



// MARK: - Extensions

extension KeyboardShortcut {
    /// Whether this shortcut conflicts with common system shortcuts
    var hasSystemConflict: Bool {
        return KeyboardShortcut.systemShortcuts.contains(self)
    }
}
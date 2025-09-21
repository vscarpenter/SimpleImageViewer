import Foundation
import SwiftUI

/// Manager for responsive thumbnail grid layout that adapts to window size
final class ResponsiveGridLayoutManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Current effective grid size based on window size and preferences
    @Published var effectiveGridSize: ThumbnailGridSize = .medium
    
    /// Whether responsive layout is enabled
    @Published var isResponsiveLayoutEnabled: Bool = true
    
    /// Current window size
    @Published var windowSize: CGSize = .zero
    
    // MARK: - Private Properties
    
    private var preferencesService: PreferencesService
    private var userPreferredGridSize: ThumbnailGridSize
    
    // MARK: - Constants
    
    /// Breakpoints for responsive layout
    private struct Breakpoints {
        static let smallWidth: CGFloat = 600
        static let mediumWidth: CGFloat = 900
        static let largeWidth: CGFloat = 1200
        
        static let smallHeight: CGFloat = 400
        static let mediumHeight: CGFloat = 600
        static let largeHeight: CGFloat = 800
    }
    
    // MARK: - Initialization
    
    init(preferencesService: PreferencesService = DefaultPreferencesService()) {
        self.preferencesService = preferencesService
        self.userPreferredGridSize = preferencesService.defaultThumbnailGridSize
        self.isResponsiveLayoutEnabled = preferencesService.useResponsiveGridLayout
        
        // Set initial effective grid size
        updateEffectiveGridSize()
    }
    
    // MARK: - Public Methods
    
    /// Update the window size and recalculate grid layout
    /// - Parameter newSize: The new window size
    func updateWindowSize(_ newSize: CGSize) {
        windowSize = newSize
        updateEffectiveGridSize()
    }
    
    /// Set the user's preferred grid size
    /// - Parameter gridSize: The preferred grid size
    func setUserPreferredGridSize(_ gridSize: ThumbnailGridSize) {
        userPreferredGridSize = gridSize
        preferencesService.defaultThumbnailGridSize = gridSize
        preferencesService.savePreferences()
        updateEffectiveGridSize()
    }
    
    /// Toggle responsive layout on/off
    /// - Parameter enabled: Whether responsive layout should be enabled
    func setResponsiveLayoutEnabled(_ enabled: Bool) {
        isResponsiveLayoutEnabled = enabled
        preferencesService.useResponsiveGridLayout = enabled
        preferencesService.savePreferences()
        updateEffectiveGridSize()
    }
    
    /// Get the optimal number of columns for the current window size
    /// - Returns: The optimal number of columns
    func getOptimalColumnCount() -> Int {
        if !isResponsiveLayoutEnabled {
            return userPreferredGridSize.columnCount
        }
        
        return calculateOptimalColumnCount(for: windowSize, gridSize: effectiveGridSize)
    }
    
    /// Get the optimal thumbnail size for the current layout
    /// - Returns: The optimal thumbnail size
    func getOptimalThumbnailSize() -> CGSize {
        if !isResponsiveLayoutEnabled {
            return userPreferredGridSize.thumbnailSize
        }
        
        return calculateOptimalThumbnailSize(for: windowSize, columnCount: getOptimalColumnCount())
    }
    
    /// Get grid columns configuration for SwiftUI LazyVGrid
    /// - Returns: Array of GridItem for LazyVGrid
    func getGridColumns() -> [GridItem] {
        let columnCount = getOptimalColumnCount()
        let spacing = effectiveGridSize.spacing
        
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)
    }
    
    // MARK: - Private Methods
    
    /// Update the effective grid size based on current settings and window size
    private func updateEffectiveGridSize() {
        if !isResponsiveLayoutEnabled {
            effectiveGridSize = userPreferredGridSize
            return
        }
        
        // Calculate responsive grid size based on window dimensions
        let responsiveSize = calculateResponsiveGridSize(for: windowSize)
        
        // Respect user preference as a baseline, but allow responsive adjustments
        effectiveGridSize = combineUserPreferenceWithResponsive(
            userPreference: userPreferredGridSize,
            responsive: responsiveSize
        )
    }
    
    /// Calculate responsive grid size based on window size
    /// - Parameter windowSize: The current window size
    /// - Returns: The recommended grid size for the window
    private func calculateResponsiveGridSize(for windowSize: CGSize) -> ThumbnailGridSize {
        let width = windowSize.width
        let height = windowSize.height
        
        // Use the smaller dimension to determine grid size for better balance
        let minDimension = min(width, height)
        
        if minDimension < Breakpoints.smallWidth || height < Breakpoints.smallHeight {
            return .small
        } else if minDimension < Breakpoints.mediumWidth || height < Breakpoints.mediumHeight {
            return .medium
        } else {
            return .large
        }
    }
    
    /// Combine user preference with responsive recommendation
    /// - Parameters:
    ///   - userPreference: The user's preferred grid size
    ///   - responsive: The responsive recommendation
    /// - Returns: The combined grid size
    private func combineUserPreferenceWithResponsive(
        userPreference: ThumbnailGridSize,
        responsive: ThumbnailGridSize
    ) -> ThumbnailGridSize {
        // If window is very small, force small grid regardless of preference
        if windowSize.width < Breakpoints.smallWidth * 0.8 {
            return .small
        }
        
        // If window is very large, allow large grid even if user prefers smaller
        if windowSize.width > Breakpoints.largeWidth * 1.2 && userPreference != .small {
            return .large
        }
        
        // For medium-sized windows, respect user preference more
        return userPreference
    }
    
    /// Calculate optimal column count for given window size and grid size
    /// - Parameters:
    ///   - windowSize: The window size
    ///   - gridSize: The grid size configuration
    /// - Returns: The optimal number of columns
    private func calculateOptimalColumnCount(for windowSize: CGSize, gridSize: ThumbnailGridSize) -> Int {
        let availableWidth = windowSize.width - (gridSize.padding * 2)
        let thumbnailWidth = gridSize.thumbnailSize.width
        let spacing = gridSize.spacing
        
        // Calculate how many thumbnails can fit
        let maxColumns = Int((availableWidth + spacing) / (thumbnailWidth + spacing))
        
        // Ensure we have at least 1 column and don't exceed the grid size's default
        let minColumns = 1
        let maxAllowedColumns = gridSize.columnCount * 2 // Allow up to 2x the default for very wide windows
        
        return max(minColumns, min(maxColumns, maxAllowedColumns))
    }
    
    /// Calculate optimal thumbnail size for given window size and column count
    /// - Parameters:
    ///   - windowSize: The window size
    ///   - columnCount: The number of columns
    /// - Returns: The optimal thumbnail size
    private func calculateOptimalThumbnailSize(for windowSize: CGSize, columnCount: Int) -> CGSize {
        let availableWidth = windowSize.width - (effectiveGridSize.padding * 2)
        let totalSpacing = effectiveGridSize.spacing * CGFloat(columnCount - 1)
        let thumbnailWidth = (availableWidth - totalSpacing) / CGFloat(columnCount)
        
        // Maintain aspect ratio (4:3)
        let aspectRatio: CGFloat = 4.0 / 3.0
        let thumbnailHeight = thumbnailWidth / aspectRatio
        
        // Clamp to reasonable bounds
        let minSize: CGFloat = 80
        let maxSize: CGFloat = 300
        
        let clampedWidth = max(minSize, min(maxSize, thumbnailWidth))
        let clampedHeight = max(minSize * 0.75, min(maxSize * 0.75, thumbnailHeight))
        
        return CGSize(width: clampedWidth, height: clampedHeight)
    }
}

// MARK: - Grid Size Extensions

extension ThumbnailGridSize {
    /// Get a responsive variant of this grid size
    /// - Parameter windowSize: The current window size
    /// - Returns: A potentially adjusted grid size for the window
    func responsiveVariant(for windowSize: CGSize) -> ThumbnailGridSize {
        let width = windowSize.width
        
        // Very narrow windows should use small thumbnails
        if width < 500 {
            return .small
        }
        
        // Very wide windows can use larger thumbnails
        if width > 1400 && self != .small {
            return .large
        }
        
        // Otherwise, keep the current size
        return self
    }
    
    /// Get the optimal column count for a given window width
    /// - Parameter windowWidth: The available window width
    /// - Returns: The optimal number of columns
    func optimalColumnCount(for windowWidth: CGFloat) -> Int {
        let availableWidth = windowWidth - (padding * 2)
        let thumbnailWidth = thumbnailSize.width
        let spacing = self.spacing
        
        let maxColumns = Int((availableWidth + spacing) / (thumbnailWidth + spacing))
        
        // Ensure reasonable bounds
        return max(1, min(maxColumns, columnCount * 2))
    }
}

// MARK: - Responsive Layout Utilities

extension ResponsiveGridLayoutManager {
    /// Get layout metrics for the current configuration
    struct LayoutMetrics {
        let gridSize: ThumbnailGridSize
        let columnCount: Int
        let thumbnailSize: CGSize
        let spacing: CGFloat
        let padding: CGFloat
        let isResponsive: Bool
    }
    
    /// Get current layout metrics
    /// - Returns: The current layout metrics
    func getCurrentLayoutMetrics() -> LayoutMetrics {
        return LayoutMetrics(
            gridSize: effectiveGridSize,
            columnCount: getOptimalColumnCount(),
            thumbnailSize: getOptimalThumbnailSize(),
            spacing: effectiveGridSize.spacing,
            padding: effectiveGridSize.padding,
            isResponsive: isResponsiveLayoutEnabled
        )
    }
    
    /// Check if the layout should be updated for a new window size
    /// - Parameter newSize: The new window size
    /// - Returns: True if layout should be updated
    func shouldUpdateLayout(for newSize: CGSize) -> Bool {
        let sizeDifference = abs(newSize.width - windowSize.width) + abs(newSize.height - windowSize.height)

        // Update if the size difference is significant (more than 50 points)
        return sizeDifference > 50
    }
}
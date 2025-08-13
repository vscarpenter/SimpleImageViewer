import SwiftUI

/// Heart indicator overlay component for thumbnails showing favorite status
struct HeartIndicatorView: View {
    // MARK: - Properties
    
    /// Whether the image is favorited
    let isFavorite: Bool
    
    /// Size of the thumbnail for scaling the indicator
    let thumbnailSize: CGSize
    
    /// Whether to show the indicator (based on hover/selection state)
    let isVisible: Bool
    
    // MARK: - Constants
    
    private var indicatorSize: CGFloat {
        // Scale heart size based on thumbnail size, with min/max bounds
        let baseSize = min(thumbnailSize.width, thumbnailSize.height) * 0.15
        return max(12, min(baseSize, 24))
    }
    
    private var cornerOffset: CGFloat {
        // Position from corner, scaled with thumbnail size
        let baseOffset = min(thumbnailSize.width, thumbnailSize.height) * 0.08
        return max(6, min(baseOffset, 12))
    }
    
    var body: some View {
        ZStack {
            if isVisible && isFavorite {
                heartIndicator
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .allowsHitTesting(false) // Don't interfere with thumbnail interactions
    }
    
    private var heartIndicator: some View {
        VStack {
            HStack {
                Spacer()
                heartIcon
            }
            Spacer()
        }
        .padding(cornerOffset)
    }
    
    private var heartIcon: some View {
        ZStack {
            // Background circle for better visibility with high contrast support
            Circle()
                .fill(heartIndicatorBackgroundColor)
                .frame(width: indicatorSize + 4, height: indicatorSize + 4)
                .shadowSubtle()
            
            // Heart icon with high contrast support
            Image(systemName: "heart.fill")
                .font(.system(size: indicatorSize * 0.7, weight: .medium))
                .foregroundColor(heartIndicatorColor)
                .apply { image in
                    if #available(macOS 14.0, *), !AccessibilityService.shared.isReducedMotionEnabled {
                        image.symbolEffect(.pulse, options: .nonRepeating)
                    } else {
                        image
                    }
                }
        }
        .accessibilityLabel(heartIndicatorAccessibilityLabel)
        .accessibilityHidden(true) // Parent thumbnail handles accessibility
    }
    
    // MARK: - Accessibility Helpers
    
    private var heartIndicatorBackgroundColor: Color {
        return AccessibilityService.shared.heartIndicatorBackgroundColor()
    }
    
    private var heartIndicatorColor: Color {
        return AccessibilityService.shared.heartIndicatorColor(isFavorite: isFavorite)
    }
    
    private var heartIndicatorAccessibilityLabel: String {
        return AccessibilityService.shared.favoriteStatusDescription(
            isFavorite: isFavorite,
            itemName: "image"
        )
    }
}

// MARK: - View Extension for Conditional Modifiers

extension View {
    /// Apply a conditional modifier to the view
    /// - Parameter transform: The transformation to apply
    /// - Returns: The modified view
    func apply<T: View>(@ViewBuilder _ transform: (Self) -> T) -> T {
        transform(self)
    }
}

// MARK: - Preview

#Preview("Heart Indicator - Various Sizes") {
    VStack(spacing: 20) {
        // Small thumbnail
        HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 80, height: 80),
            isVisible: true
        )
        .background(Color.gray.opacity(0.3))
        .overlay(
            Text("80x80")
                .font(.caption)
                .foregroundColor(.white)
        )
        
        // Medium thumbnail
        HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        .background(Color.gray.opacity(0.3))
        .overlay(
            Text("120x120")
                .font(.caption)
                .foregroundColor(.white)
        )
        
        // Large thumbnail
        HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 200, height: 200),
            isVisible: true
        )
        .background(Color.gray.opacity(0.3))
        .overlay(
            Text("200x200")
                .font(.caption)
                .foregroundColor(.white)
        )
    }
    .padding()
}

#Preview("Heart Indicator - States") {
    HStack(spacing: 20) {
        // Not visible
        HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: false
        )
        .background(Color.gray.opacity(0.3))
        .overlay(
            Text("Hidden")
                .font(.caption)
                .foregroundColor(.white)
        )
        
        // Visible and favorited
        HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        .background(Color.gray.opacity(0.3))
        .overlay(
            Text("Favorited")
                .font(.caption)
                .foregroundColor(.white)
        )
        
        // Visible but not favorited
        HeartIndicatorView(
            isFavorite: false,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        .background(Color.gray.opacity(0.3))
        .overlay(
            Text("Not Favorited")
                .font(.caption)
                .foregroundColor(.white)
        )
    }
    .padding()
}
import SwiftUI

// MARK: - Toolbar Button Style
struct ToolbarButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .systemAccent : .appText)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                configuration.isPressed 
                                ? Color.systemAccent.glassEffect(opacity: 0.2)
                                : (isHovered ? Color.appGlassPrimary : Color.appGlassSecondary)
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        configuration.isPressed 
                        ? Color.systemAccent.glassBorder(intensity: 0.4)
                        : Color.appGlassBorder, 
                        lineWidth: 0.5
                    )
            )
            .overlay(
                // Subtle highlight on top edge for depth
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Color.appGlassHighlight,
                        lineWidth: 0.5
                    )
                    .mask(
                        Rectangle()
                            .frame(height: 1)
                            .offset(y: -3.5)
                    )
            )
            .scaleEffect(
                configuration.isPressed ? 0.92 : (isHovered ? 1.02 : 1.0)
            )
            .shadow(
                color: Color.appGlassShadow,
                radius: configuration.isPressed ? 2 : (isHovered ? 6 : 4),
                x: 0,
                y: configuration.isPressed ? 1 : (isHovered ? 3 : 2)
            )
            .animation(
                .spring(response: 0.3, dampingFraction: 0.9), 
                value: configuration.isPressed
            )
            .animation(
                .easeInOut(duration: 0.2), 
                value: isHovered
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Compact Toolbar Button Style
struct CompactToolbarButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .systemAccent : .appText)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                configuration.isPressed 
                                ? Color.systemAccent.glassEffect(opacity: 0.2)
                                : (isHovered ? Color.appGlassPrimary : Color.appGlassTertiary)
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        configuration.isPressed 
                        ? Color.systemAccent.glassBorder(intensity: 0.4)
                        : Color.appGlassBorder, 
                        lineWidth: 0.5
                    )
            )
            .overlay(
                // Subtle highlight on top edge for depth
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        Color.appGlassHighlight,
                        lineWidth: 0.5
                    )
                    .mask(
                        Rectangle()
                            .frame(height: 1)
                            .offset(y: -2.5)
                    )
            )
            .scaleEffect(
                configuration.isPressed ? 0.94 : (isHovered ? 1.02 : 1.0)
            )
            .shadow(
                color: Color.appGlassShadow,
                radius: configuration.isPressed ? 1 : (isHovered ? 4 : 2),
                x: 0,
                y: configuration.isPressed ? 0.5 : (isHovered ? 2 : 1)
            )
            .animation(
                .spring(response: 0.3, dampingFraction: 0.9), 
                value: configuration.isPressed
            )
            .animation(
                .easeInOut(duration: 0.2), 
                value: isHovered
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
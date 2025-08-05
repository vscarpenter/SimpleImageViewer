import SwiftUI

// MARK: - Toolbar Button Style
struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .appAccent : .appText)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.2)
                        : Color.appButtonBackground.opacity(0.8)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.3)
                        : Color.appBorder.opacity(0.2), 
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Compact Toolbar Button Style
struct CompactToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .appAccent : .appText)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.2)
                        : Color.appButtonBackground.opacity(0.8)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.3)
                        : Color.appBorder.opacity(0.2), 
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
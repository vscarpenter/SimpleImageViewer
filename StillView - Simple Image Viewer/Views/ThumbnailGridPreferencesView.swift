import SwiftUI

/// Preferences view for thumbnail grid configuration
struct ThumbnailGridPreferencesView: View {
    // MARK: - Properties
    
    @StateObject private var layoutManager = ResponsiveGridLayoutManager()
    @State private var selectedGridSize: ThumbnailGridSize
    @State private var isResponsiveLayoutEnabled: Bool
    
    // MARK: - Initialization
    
    init() {
        let preferencesService = DefaultPreferencesService()
        _selectedGridSize = State(initialValue: preferencesService.defaultThumbnailGridSize)
        _isResponsiveLayoutEnabled = State(initialValue: preferencesService.useResponsiveGridLayout)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Thumbnail Grid")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.appText)
                
                Text("Configure how thumbnails are displayed in grid view")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
            
            // Responsive Layout Toggle
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Responsive Layout", isOn: $isResponsiveLayoutEnabled)
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: isResponsiveLayoutEnabled) { newValue in
                        layoutManager.setResponsiveLayoutEnabled(newValue)
                    }
                
                Text("Automatically adjust thumbnail size based on window size")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                    .padding(.leading, 4)
            }
            
            Divider()
                .background(Color.appBorder)
            
            // Grid Size Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Default Thumbnail Size")
                    .font(.headline)
                    .foregroundColor(.appText)
                
                if !isResponsiveLayoutEnabled {
                    Text("Choose your preferred thumbnail size")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                } else {
                    Text("Base size for responsive layout (may adjust automatically)")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }
                
                // Grid Size Options
                VStack(spacing: 12) {
                    ForEach(ThumbnailGridSize.allCases, id: \.self) { gridSize in
                        ThumbnailSizeOption(
                            gridSize: gridSize,
                            isSelected: selectedGridSize == gridSize,
                            isEnabled: !isResponsiveLayoutEnabled || true, // Always enabled for base size
                            onSelect: {
                                selectedGridSize = gridSize
                                layoutManager.setUserPreferredGridSize(gridSize)
                            }
                        )
                    }
                }
            }
            
            Divider()
                .background(Color.appBorder)
            
            // Preview Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(.appText)
                
                ThumbnailGridPreview(
                    gridSize: selectedGridSize,
                    isResponsive: isResponsiveLayoutEnabled
                )
            }
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: 500)
        .background(Color.appBackground)
    }
}

/// Individual thumbnail size option
private struct ThumbnailSizeOption: View {
    let gridSize: ThumbnailGridSize
    let isSelected: Bool
    let isEnabled: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(Color.appBorder, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if isSelected {
                    Circle()
                        .fill(Color.systemAccent)
                        .frame(width: 12, height: 12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Size info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(gridSize.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isEnabled ? .appText : .appSecondaryText)
                    
                    Spacer()
                    
                    Text("\(Int(gridSize.thumbnailSize.width))×\(Int(gridSize.thumbnailSize.height))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.appSecondaryText)
                }
                
                Text("\(gridSize.columnCount) columns • \(Int(gridSize.spacing))pt spacing")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
            
            // Visual preview
            ThumbnailSizePreview(gridSize: gridSize)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected ? Color.systemAccent.opacity(0.1) :
                    isHovered ? Color.appSecondaryBackground : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.systemAccent.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isEnabled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onSelect()
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering && isEnabled
            }
        }
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(gridSize.displayName) thumbnail size")
        .accessibilityHint("Tap to select this thumbnail size")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Visual preview of thumbnail size
private struct ThumbnailSizePreview: View {
    let gridSize: ThumbnailGridSize
    
    var body: some View {
        HStack(spacing: gridSize.spacing / 2) {
            ForEach(0..<min(3, gridSize.columnCount), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.systemAccent.opacity(0.3))
                    .frame(
                        width: gridSize.thumbnailSize.width / 8,
                        height: gridSize.thumbnailSize.height / 8
                    )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appTertiaryBackground)
        )
    }
}

/// Preview of the thumbnail grid layout
private struct ThumbnailGridPreview: View {
    let gridSize: ThumbnailGridSize
    let isResponsive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(gridSize.columnCount, 4)),
                spacing: 4
            ) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.systemAccent.opacity(0.4),
                                    Color.systemAccent.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 24)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 8))
                                .foregroundColor(.systemAccent)
                        )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appTertiaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            )
            
            // Layout info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Layout")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                    
                    Text(isResponsive ? "Responsive" : "Fixed")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.appText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Columns")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                    
                    Text("\(gridSize.columnCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.appText)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Preview

#Preview {
    ThumbnailGridPreferencesView()
        .frame(width: 500, height: 600)
}

#Preview("Dark Mode") {
    ThumbnailGridPreferencesView()
        .frame(width: 500, height: 600)
        .preferredColorScheme(.dark)
}
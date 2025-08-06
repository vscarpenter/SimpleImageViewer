import SwiftUI
import AppKit

/// View for selecting folders and managing recent folders
struct FolderSelectionView: View {
    @StateObject private var viewModel = FolderSelectionViewModel()
    @State private var showingErrorAlert = false
    
    var body: some View {
        ZStack {
            // Adaptive gradient background with context menu
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.appBackground,
                    Color.appSecondaryBackground,
                    Color.appTertiaryBackground
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .contextMenu {
                folderSelectionContextMenu
            }
            
            // Subtle texture overlay with adaptive colors
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.appBackground.opacity(0.1),
                    Color.clear,
                    Color.appSecondaryBackground.opacity(0.02)
                ]),
                center: .topTrailing,
                startRadius: 100,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 32) {
                    headerView
                    folderSelectionButton
                    
                    if viewModel.isScanning {
                        scanningView
                    }
                    
                    if !viewModel.recentFolders.isEmpty && !viewModel.isScanning {
                        recentFoldersView
                    }
                    
                    // Add some bottom padding instead of Spacer for proper scrolling
                    Color.clear
                        .frame(height: 20)
                }
                .padding(32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped() // Ensure content doesn't extend beyond bounds
        .alert("Error", isPresented: $showingErrorAlert, presenting: viewModel.currentError) { error in
            Button("OK") {
                viewModel.clearError()
            }
            .accessibilityLabel("Dismiss error")
            
            if case .folderAccessDenied = error {
                Button("Try Again") {
                    viewModel.selectFolder()
                }
                .accessibilityLabel("Try selecting folder again")
            }
        } message: { error in
            VStack(alignment: .leading, spacing: 8) {
                Text(error.localizedDescription)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: viewModel.currentError) { error in
            showingErrorAlert = error != nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Folder selection view")
    }
    
    // MARK: - Context Menu
    
    private var folderSelectionContextMenu: some View {
        Group {
            Button(action: {
                viewModel.selectFolder()
            }) {
                Label("Select Folder...", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Divider()
            
            if !viewModel.recentFolders.isEmpty {
                Menu("Recent Folders") {
                    ForEach(viewModel.recentFolders.prefix(5), id: \.absoluteString) { folderURL in
                        Button(action: {
                            viewModel.selectRecentFolder(folderURL)
                        }) {
                            Label(folderURL.lastPathComponent, systemImage: "folder")
                        }
                    }
                    
                    if viewModel.recentFolders.count > 5 {
                        Text("... and \(viewModel.recentFolders.count - 5) more")
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Button(action: {
                        viewModel.clearRecentFolders()
                    }) {
                        Label("Clear All Recent", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }
            }
            
            Divider()
            
            Button(action: {
                // Open preferences (placeholder)
                ErrorHandlingService.shared.showNotification(
                    "Preferences window will be available in a future update",
                    type: .info
                )
            }) {
                Label("Preferences...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // App logo - use actual app icon
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.appBorder.opacity(0.3), radius: 12, x: 0, y: 6)
                    .accessibilityHidden(true)
            } else {
                // Fallback with original app icon design
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.4, green: 0.49, blue: 0.92), // #667eea
                                    Color(red: 0.46, green: 0.29, blue: 0.64)  // #764ba2
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.appBorder.opacity(0.3), radius: 12, x: 0, y: 6)
                    
                    VStack(spacing: 6) {
                        // Photo frame
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 64, height: 48)
                            .overlay(
                                HStack {
                                    VStack {
                                        Circle()
                                            .fill(Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.7))
                                            .frame(width: 12, height: 12)
                                        Spacer()
                                    }
                                    .padding(.top, 6)
                                    .padding(.leading, 8)
                                    Spacer()
                                }
                            )
                        
                        // Bottom bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 56, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
            
            VStack(spacing: 8) {
                Text("Select Image Folder")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.appText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Choose a folder containing images to browse")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                    .accessibilityLabel("Choose a folder containing images to browse")
            }
        }
        .padding(.top, 12)
    }
    
    // MARK: - Folder Selection Button
    private var folderSelectionButton: some View {
        Button(action: {
            viewModel.selectFolder()
        }) {
            HStack(spacing: 16) {
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .medium))
                Text("Browse for Folder...")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.appAccent,
                        Color.appAccent.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: Color.appAccent.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(viewModel.isScanning ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isScanning)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isScanning)
        .help("Select a folder containing images to browse")
        .accessibilityLabel("Browse for folder")
        .accessibilityHint("Opens a dialog to select a folder containing images")
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.0)
                .tint(.appAccent)
                .accessibilityLabel("Scanning folder")
            
            VStack(spacing: 8) {
                Text("Scanning folder...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appText)
                
                if viewModel.scanProgress > 0 {
                    ProgressView(value: viewModel.scanProgress)
                        .frame(width: 240)
                        .tint(.appAccent)
                        .accessibilityLabel("Scan progress")
                        .accessibilityValue("\(Int(viewModel.scanProgress * 100)) percent complete")
                }
                
                if viewModel.imageCount > 0 {
                    Text("\(viewModel.imageCount) images found")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.appSecondaryText)
                        .accessibilityLabel("\(viewModel.imageCount) images found")
                }
            }
            
            Button("Cancel") {
                viewModel.cancelScanning()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.appSecondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.appSecondaryText.opacity(0.1))
            )
            .help("Stop scanning the current folder")
            .accessibilityLabel("Cancel scanning")
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appBackground.opacity(0.9),
                            Color.appBackground.opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appBackground)
                        .shadow(color: Color.appBorder.opacity(0.3), radius: 8, x: 0, y: 2)
                )
        )
    }
    
    // MARK: - Recent Folders View
    private var recentFoldersView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Recent Folders")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.appText)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button("Clear All") {
                    viewModel.clearRecentFolders()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appSecondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.appSecondaryText.opacity(0.1))
                )
                .help("Remove all folders from the recent list")
                .accessibilityLabel("Clear all recent folders")
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.recentFolders, id: \.absoluteString) { folderURL in
                    RecentFolderRow(
                        folderURL: folderURL,
                        onSelect: { viewModel.selectRecentFolder(folderURL) },
                        onRemove: { viewModel.removeRecentFolder(folderURL) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appBackground.opacity(0.8),
                            Color.appBackground.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appBackground)
                        .shadow(color: Color.appBorder.opacity(0.3), radius: 12, x: 0, y: 4)
                )
        )
    }
}

/// Row view for displaying recent folders
private struct RecentFolderRow: View {
    let folderURL: URL
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced folder icon with background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appAccent.opacity(0.2),
                                Color.appAccent.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.appAccent)
                    .accessibilityHidden(true)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folderURL.lastPathComponent)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(folderURL.path)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.appSecondaryText)
                    .opacity(0.8)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.appSecondaryText)
                        .opacity(0.7)
                }
                .buttonStyle(.plain)
                .help("Remove \(folderURL.lastPathComponent) from recent folders")
                .accessibilityLabel("Remove \(folderURL.lastPathComponent) from recent folders")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isHovered ? 
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appAccent.opacity(0.08),
                            Color.appAccent.opacity(0.04)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHovered ? Color.appAccent.opacity(0.2) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .help("Click to open \(folderURL.lastPathComponent)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recent folder: \(folderURL.lastPathComponent)")
        .accessibilityHint("Double-tap to select this folder")
        .accessibilityAction(named: "Select") {
            onSelect()
        }
        .accessibilityAction(named: "Remove") {
            onRemove()
        }
    }
}

#Preview {
    FolderSelectionView()
        .frame(width: 600, height: 500)
}

#Preview("With Recent Folders") {
    let viewModel = FolderSelectionViewModel()
    // Note: In a real preview, you'd inject mock data
    return FolderSelectionView()
        .frame(width: 600, height: 500)
}

#Preview("Scanning State") {
    let viewModel = FolderSelectionViewModel()
    // Note: In a real preview, you'd set isScanning to true
    return FolderSelectionView()
        .frame(width: 600, height: 500)
}
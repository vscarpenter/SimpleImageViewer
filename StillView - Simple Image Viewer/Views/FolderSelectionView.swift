import SwiftUI

/// View for selecting folders and managing recent folders
struct FolderSelectionView: View {
    @StateObject private var viewModel = FolderSelectionViewModel()
    @State private var showingErrorAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            folderSelectionButton
            
            if viewModel.isScanning {
                scanningView
            }
            
            if !viewModel.recentFolders.isEmpty && !viewModel.isScanning {
                recentFoldersView
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text("Select Image Folder")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .accessibilityAddTraits(.isHeader)
            
            Text("Choose a folder containing images to browse")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Choose a folder containing images to browse")
        }
        .padding(.top, 20)
    }
    
    // MARK: - Folder Selection Button
    private var folderSelectionButton: some View {
        Button(action: {
            viewModel.selectFolder()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.title3)
                Text("Browse for Folder...")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isScanning)
        .help("Select a folder containing images to browse")
        .accessibilityLabel("Browse for folder")
        .accessibilityHint("Opens a dialog to select a folder containing images")
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .accessibilityLabel("Scanning folder")
            
            VStack(spacing: 4) {
                Text("Scanning folder...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if viewModel.scanProgress > 0 {
                    ProgressView(value: viewModel.scanProgress)
                        .frame(width: 200)
                        .accessibilityLabel("Scan progress")
                        .accessibilityValue("\(Int(viewModel.scanProgress * 100)) percent complete")
                }
                
                if viewModel.imageCount > 0 {
                    Text("\(viewModel.imageCount) images found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("\(viewModel.imageCount) images found")
                }
            }
            
            Button("Cancel") {
                viewModel.cancelScanning()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .help("Stop scanning the current folder")
            .accessibilityLabel("Cancel scanning")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Recent Folders View
    private var recentFoldersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Folders")
                    .font(.headline)
                    .foregroundColor(.white)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button("Clear All") {
                    viewModel.clearRecentFolders()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .help("Remove all folders from the recent list")
                .accessibilityLabel("Clear all recent folders")
            }
            
            LazyVStack(spacing: 8) {
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
    }
}

/// Row view for displaying recent folders
private struct RecentFolderRow: View {
    let folderURL: URL
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folderURL.lastPathComponent)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(folderURL.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove \(folderURL.lastPathComponent) from recent folders")
                .accessibilityLabel("Remove \(folderURL.lastPathComponent) from recent folders")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
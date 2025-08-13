import SwiftUI
import AppKit

/// View for displaying and managing favorite images
struct FavoritesView: View {
    // MARK: - Properties
    
    @StateObject private var favoritesViewModel = FavoritesViewModel(
        favoritesService: DefaultFavoritesService.shared
    )
    @StateObject private var imageViewerViewModel = ImageViewerViewModel(
        favoritesService: DefaultFavoritesService.shared
    )
    @StateObject private var keyboardHandler = KeyboardHandler()
    @State private var showingErrorAlert = false
    @State private var selectedImageIndex: Int = 0
    @State private var selectedImages: Set<ImageFile> = []
    @State private var isSelectionMode = false
    @State private var showingBatchRemovalConfirmation = false
    @State private var showingSingleRemovalConfirmation = false
    @State private var showingRemoveAllConfirmation = false
    @State private var imageToRemove: ImageFile?
    @State private var refreshTrigger = false
    
    /// Callback when an image is selected for full-screen viewing
    let onImageSelected: (FolderContent, ImageFile) -> Void
    
    /// Callback when returning to folder selection
    let onBackToFolderSelection: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
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
            
            VStack(spacing: 0) {
                headerView
                
                Group {
                    let isLoading = favoritesViewModel.isLoading
                    let favoriteFiles = favoritesViewModel.favoriteImageFiles
                    let inaccessibleFavorites = favoritesViewModel.inaccessibleFavorites
                    let hasAnyFavorites = favoritesViewModel.hasFavorites
                    let count = favoriteFiles.count
                    
                    let _ = print("DEBUG: FavoritesView.body - isLoading: \(isLoading), accessible: \(count), inaccessible: \(inaccessibleFavorites.count), hasAny: \(hasAnyFavorites)")
                    
                    if isLoading {
                        loadingView
                    } else if count == 0 && inaccessibleFavorites.isEmpty {
                        emptyStateView
                    } else {
                        favoritesContentView
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingErrorAlert, presenting: favoritesViewModel.currentError) { error in
            Button("OK") {
                favoritesViewModel.clearError()
            }
            .accessibilityLabel("Dismiss error")
            
            Button("Retry") {
                favoritesViewModel.refreshFavorites()
            }
            .accessibilityLabel("Retry loading favorites")
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert("Remove Favorites", isPresented: $showingBatchRemovalConfirmation) {
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
            .accessibilityLabel("Cancel removal")
            
            Button("Remove", role: .destructive) {
                batchRemoveSelectedFavorites()
            }
            .accessibilityLabel("Confirm removal")
        } message: {
            Text("Are you sure you want to remove \(selectedImages.count) favorite\(selectedImages.count == 1 ? "" : "s")? This action cannot be undone.")
        }
        .alert("Remove Favorite", isPresented: $showingSingleRemovalConfirmation, presenting: imageToRemove) { imageFile in
            Button("Cancel", role: .cancel) {
                imageToRemove = nil
            }
            .accessibilityLabel("Cancel removal")
            
            Button("Remove", role: .destructive) {
                if let imageFile = imageToRemove {
                    removeFavoriteImmediately(imageFile)
                }
                imageToRemove = nil
            }
            .accessibilityLabel("Confirm removal")
        } message: { imageFile in
            Text("Are you sure you want to remove \"\(imageFile.name)\" from favorites? This action cannot be undone.")
        }
        .alert("Remove All Favorites", isPresented: $showingRemoveAllConfirmation) {
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
            .accessibilityLabel("Cancel removal")
            
            Button("Remove All", role: .destructive) {
                removeAllFavorites()
            }
            .accessibilityLabel("Confirm remove all")
        } message: {
            Text("Are you sure you want to remove all \(favoritesViewModel.favoriteImageFiles.count) favorites? This action cannot be undone.")
        }
        .onChange(of: favoritesViewModel.currentError) { error in
            showingErrorAlert = error != nil
        }
        .onChange(of: favoritesViewModel.favoriteImageFiles) { newFavorites in
            print("DEBUG: FavoritesView.onChange - favoriteImageFiles changed to count: \(newFavorites.count)")
            handleFavoritesListChange(newFavorites)
        }
        .onChange(of: favoritesViewModel.isLoading) { isLoading in
            print("DEBUG: FavoritesView.onChange - isLoading changed to: \(isLoading)")
        }
        .onAppear {
            print("DEBUG: FavoritesView.onAppear - Setting up view")
            setupKeyboardNavigation()
            // Only load favorites if not already loaded or loading
            if favoritesViewModel.favoriteImageFiles.isEmpty && !favoritesViewModel.isLoading {
                print("DEBUG: FavoritesView.onAppear - Loading favorites (first time)")
                favoritesViewModel.loadFavorites()
            }
        }
        .onReceive(favoritesViewModel.$favoriteImageFiles) { newFavorites in
            print("DEBUG: FavoritesView.onReceive - favoriteImageFiles updated to count: \(newFavorites.count)")
            // Force view refresh
            refreshTrigger.toggle()
        }
        .id(refreshTrigger)
        .keyboardHandling(keyboardHandler)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Favorites view")
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                // Back button
                Button(action: onBackToFolderSelection) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.systemAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.systemAccent.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .help("Return to folder selection")
                .accessibilityLabel("Back to folder selection")
                .accessibilityHint("Returns to the main folder selection view")
                .accessibilityAddTraits(.isButton)
                
                Spacer()
                
                // Selection mode toggle
                if !favoritesViewModel.favoriteImageFiles.isEmpty {
                    Button(action: {
                        toggleSelectionMode()
                    }) {
                        Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.systemAccent)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.systemAccent.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help(isSelectionMode ? "Exit selection mode" : "Enter selection mode")
                    .accessibilityLabel(selectionModeAccessibilityLabel)
                    .accessibilityHint(selectionModeAccessibilityHint)
                    .accessibilityValue(selectionModeAccessibilityValue)
                    .accessibilityAddTraits(.isButton)
                }
                
                // Batch remove button (only visible in selection mode with selections)
                if isSelectionMode && !selectedImages.isEmpty {
                    Button(action: {
                        showingBatchRemovalConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Remove selected favorites")
                    .accessibilityLabel("Remove selected favorites")
                }
                
                // Remove all button (only visible when not in selection mode and has favorites)
                if !isSelectionMode && !favoritesViewModel.favoriteImageFiles.isEmpty {
                    Button(action: {
                        showingRemoveAllConfirmation = true
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Remove all favorites")
                    .accessibilityLabel("Remove all favorites")
                }
                
                // Refresh button
                Button(action: {
                    favoritesViewModel.refreshFavorites()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.systemAccent)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.systemAccent.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .help("Refresh favorites")
                .accessibilityLabel("Refresh favorites")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Title section
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.systemAccent)
                    
                    Text("Favorites")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.appText)
                }
                .accessibilityAddTraits(.isHeader)
                
                if !favoritesViewModel.favoriteImageFiles.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(favoritesViewModel.favoriteImageFiles.count) favorite\(favoritesViewModel.favoriteImageFiles.count == 1 ? "" : "s")")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.appSecondaryText)
                            .opacity(0.8)
                        
                        if isSelectionMode && !selectedImages.isEmpty {
                            Text("• \(selectedImages.count) selected")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.systemAccent)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.systemAccent)
                .accessibilityLabel("Loading favorites")
            
            Text("Loading favorites...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.appText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Empty state icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.systemAccent.opacity(0.1),
                                Color.systemAccent.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.systemAccent.opacity(0.6))
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 12) {
                Text("No Favorites Yet")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.appText)
                
                Text("Start browsing images and tap the heart icon to add them to your favorites.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                    .frame(maxWidth: 400)
            }
            
            Button(action: onBackToFolderSelection) {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 16, weight: .medium))
                    Text("Browse Images")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.systemAccent,
                            Color.systemAccent.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.systemAccent.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 280)
            .help("Go back to browse for image folders")
            .accessibilityLabel("Browse images")
            .accessibilityHint("Returns to folder selection to browse images")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
    
    // MARK: - Favorites Content View
    
    private var favoritesContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Accessible favorites section
                if favoritesViewModel.hasAccessibleFavorites {
                    accessibleFavoritesSection
                }
                
                // Inaccessible favorites section
                if favoritesViewModel.hasInaccessibleFavorites {
                    inaccessibleFavoritesSection
                }
                
                // Bottom padding for better scrolling experience
                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var accessibleFavoritesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if favoritesViewModel.hasInaccessibleFavorites {
                Text("Available Favorites")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            favoritesGridView
        }
    }
    
    private var inaccessibleFavoritesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Favorites Requiring Access")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("These favorites are from folders that need permission to access.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            // Group inaccessible favorites by folder
            let folderGroups = Dictionary(grouping: favoritesViewModel.inaccessibleFavorites) { favorite in
                favorite.originalURL.deletingLastPathComponent().path
            }
            
            ForEach(Array(folderGroups.keys.sorted()), id: \.self) { folderPath in
                inaccessibleFolderView(folderPath: folderPath, favorites: folderGroups[folderPath] ?? [])
            }
        }
    }
    
    private func inaccessibleFolderView(folderPath: String, favorites: [FavoriteImageFile]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(URL(fileURLWithPath: folderPath).lastPathComponent)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(folderPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                Button("Grant Access") {
                    favoritesViewModel.requestAccessToFolder(folderPath)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Show favorite names in this folder
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: 8)
            ], spacing: 8) {
                ForEach(favorites, id: \.originalURL) { favorite in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            )
                        
                        Text(favorite.name)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Favorites Grid View
    
    private var favoritesGridView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 150), spacing: 16)
        ], spacing: 16) {
            ForEach(favoritesViewModel.favoriteImageFiles, id: \.url) { imageFile in
                VStack(spacing: 8) {
                    // Image thumbnail with async loading
                    AsyncImage(url: imageFile.url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipped()
                            .cornerRadius(12)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
                    .onTapGesture {
                        if isSelectionMode {
                            toggleImageSelection(imageFile)
                        } else {
                            selectImageFile(imageFile)
                        }
                    }
                    .onTapGesture(count: 2) {
                        if !isSelectionMode {
                            enterFullScreenMode(with: imageFile)
                        }
                    }
                    
                    Text(imageFile.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .frame(width: 150)
                }
                .overlay(
                    // Selection indicator
                    isSelectionMode && selectedImages.contains(imageFile) ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 150, height: 150)
                    : nil
                )
            }
        }
        .contextMenu {
            favoritesContextMenu
        }
    }
    
    // MARK: - Context Menu
    
    private var favoritesContextMenu: some View {
        Group {
            if !isSelectionMode {
                Button(action: {
                    toggleSelectionMode()
                }) {
                    Label("Select Favorites", systemImage: "checkmark.circle")
                }
                
                Divider()
            }
            
            Button(action: {
                favoritesViewModel.refreshFavorites()
            }) {
                Label("Refresh Favorites", systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            if let selectedImage = favoritesViewModel.selectedFavoriteImage, !isSelectionMode {
                Button(action: {
                    requestRemovalConfirmation(for: selectedImage)
                }) {
                    Label("Remove from Favorites", systemImage: "heart.slash")
                }
                .foregroundColor(.red)
            }
            
            if isSelectionMode && !selectedImages.isEmpty {
                Button(action: {
                    showingBatchRemovalConfirmation = true
                }) {
                    Label("Remove Selected (\(selectedImages.count))", systemImage: "trash")
                }
                .foregroundColor(.red)
            }
            
            if !isSelectionMode && !favoritesViewModel.favoriteImageFiles.isEmpty {
                Button(action: {
                    showingRemoveAllConfirmation = true
                }) {
                    Label("Remove All Favorites", systemImage: "trash.fill")
                }
                .foregroundColor(.red)
            }
            
            Divider()
            
            Button(action: onBackToFolderSelection) {
                Label("Back to Folder Selection", systemImage: "chevron.left")
            }
        }
    }
    
    // MARK: - Selection Overlay
    
    private var selectionOverlay: some View {
        Group {
            if isSelectionMode {
                // This would need to be implemented as part of the grid view
                // For now, we'll handle selection through the grid interaction
                EmptyView()
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Navigation Helper Methods
    
    /// Get the currently selected image file based on index
    private func getSelectedImageFile() -> ImageFile? {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty,
              selectedImageIndex >= 0,
              selectedImageIndex < favoritesViewModel.favoriteImageFiles.count else {
            return nil
        }
        return favoritesViewModel.favoriteImageFiles[selectedImageIndex]
    }
    
    /// Select an image file and update the selection index
    private func selectImageFile(_ imageFile: ImageFile) {
        if let index = favoritesViewModel.favoriteImageFiles.firstIndex(where: { $0.url == imageFile.url }) {
            selectedImageIndex = index
            favoritesViewModel.selectFavorite(imageFile)
        }
    }
    
    /// Enter full-screen mode with the specified image
    private func enterFullScreenMode(with imageFile: ImageFile) {
        // Ensure the image is selected first
        selectImageFile(imageFile)
        
        // Create favorites content and navigate to full-screen
        if let favoritesContent = favoritesViewModel.createFavoritesContent() {
            // Update the folder content's current index to match our selection
            let updatedContent = FolderContent(
                folderURL: favoritesContent.folderURL,
                imageFiles: favoritesContent.imageFiles,
                currentIndex: selectedImageIndex
            )
            onImageSelected(updatedContent, imageFile)
        }
    }
    
    /// Setup keyboard navigation for favorites view
    private func setupKeyboardNavigation() {
        // Create a custom keyboard handler for favorites navigation
        let favoritesKeyboardHandler = FavoritesKeyboardHandler(
            onNavigateLeft: navigateLeft,
            onNavigateRight: navigateRight,
            onNavigateUp: navigateUp,
            onNavigateDown: navigateDown,
            onEnterFullScreen: enterFullScreenWithCurrentSelection,
            onBackToFolderSelection: onBackToFolderSelection,
            onToggleFavorite: toggleCurrentFavorite
        )
        
        keyboardHandler.setFavoritesHandler(favoritesKeyboardHandler)
    }
    
    /// Navigate to the previous image (left arrow)
    private func navigateLeft() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        let newIndex = selectedImageIndex > 0 ? selectedImageIndex - 1 : favoritesViewModel.favoriteImageFiles.count - 1
        selectedImageIndex = newIndex
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    /// Navigate to the next image (right arrow)
    private func navigateRight() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        let newIndex = selectedImageIndex < favoritesViewModel.favoriteImageFiles.count - 1 ? selectedImageIndex + 1 : 0
        selectedImageIndex = newIndex
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    /// Navigate up in the grid
    private func navigateUp() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        // Calculate grid columns (approximate based on typical grid layout)
        let estimatedColumns = max(1, Int(sqrt(Double(favoritesViewModel.favoriteImageFiles.count))))
        let newIndex = selectedImageIndex - estimatedColumns
        
        if newIndex >= 0 {
            selectedImageIndex = newIndex
        } else {
            // Wrap to bottom row
            let remainder = selectedImageIndex % estimatedColumns
            let lastRowStart = ((favoritesViewModel.favoriteImageFiles.count - 1) / estimatedColumns) * estimatedColumns
            selectedImageIndex = min(lastRowStart + remainder, favoritesViewModel.favoriteImageFiles.count - 1)
        }
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    /// Navigate down in the grid
    private func navigateDown() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        // Calculate grid columns (approximate based on typical grid layout)
        let estimatedColumns = max(1, Int(sqrt(Double(favoritesViewModel.favoriteImageFiles.count))))
        let newIndex = selectedImageIndex + estimatedColumns
        
        if newIndex < favoritesViewModel.favoriteImageFiles.count {
            selectedImageIndex = newIndex
        } else {
            // Wrap to top row
            let remainder = selectedImageIndex % estimatedColumns
            selectedImageIndex = remainder
        }
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    /// Enter full-screen mode with the currently selected image
    private func enterFullScreenWithCurrentSelection() {
        guard let selectedImage = getSelectedImageFile() else { return }
        enterFullScreenMode(with: selectedImage)
    }
    
    /// Toggle favorite status of the currently selected image
    private func toggleCurrentFavorite() {
        guard let selectedImage = getSelectedImageFile() else { return }
        requestRemovalConfirmation(for: selectedImage)
    }
    
    // MARK: - Selection Mode Methods
    
    /// Toggle selection mode on/off
    private func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedImages.removeAll()
        }
    }
    
    /// Toggle selection of a specific image
    private func toggleImageSelection(_ imageFile: ImageFile) {
        if selectedImages.contains(imageFile) {
            selectedImages.remove(imageFile)
        } else {
            selectedImages.insert(imageFile)
        }
    }
    
    /// Handle changes to the favorites list
    private func handleFavoritesListChange(_ newFavorites: [ImageFile]) {
        // Clean up selected images that are no longer in favorites
        selectedImages = selectedImages.intersection(Set(newFavorites))
        
        // Update selection index if needed
        if selectedImageIndex >= newFavorites.count {
            selectedImageIndex = max(0, newFavorites.count - 1)
        }
        
        // Exit selection mode if no favorites remain
        if newFavorites.isEmpty {
            isSelectionMode = false
            selectedImages.removeAll()
        }
    }
    
    /// Request confirmation for removing a single favorite
    private func requestRemovalConfirmation(for imageFile: ImageFile) {
        imageToRemove = imageFile
        showingSingleRemovalConfirmation = true
    }
    
    /// Remove a single favorite immediately (after confirmation)
    private func removeFavoriteImmediately(_ imageFile: ImageFile) {
        favoritesViewModel.removeFromFavorites(imageFile)
        
        // Update selection after removal
        updateSelectionAfterRemoval()
    }
    
    /// Batch remove selected favorites
    private func batchRemoveSelectedFavorites() {
        let imagesToRemove = Array(selectedImages)
        
        for imageFile in imagesToRemove {
            favoritesViewModel.removeFromFavorites(imageFile)
        }
        
        // Clear selection and exit selection mode
        selectedImages.removeAll()
        isSelectionMode = false
        
        // Update selection index
        updateSelectionAfterRemoval()
    }
    
    /// Remove all favorites
    private func removeAllFavorites() {
        favoritesViewModel.removeAllFavorites()
        
        // Reset all UI state
        selectedImages.removeAll()
        isSelectionMode = false
        selectedImageIndex = 0
    }
    
    /// Update selection index after removal
    private func updateSelectionAfterRemoval() {
        if favoritesViewModel.favoriteImageFiles.isEmpty {
            selectedImageIndex = 0
            selectedImages.removeAll()
            isSelectionMode = false
        } else if selectedImageIndex >= favoritesViewModel.favoriteImageFiles.count {
            selectedImageIndex = favoritesViewModel.favoriteImageFiles.count - 1
        }
        
        // Clean up selected images that no longer exist
        let currentUrls = Set(favoritesViewModel.favoriteImageFiles.map { $0.url })
        selectedImages = selectedImages.filter { currentUrls.contains($0.url) }
        
        // Exit selection mode if no images are selected
        if selectedImages.isEmpty && isSelectionMode {
            isSelectionMode = false
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private var selectionModeAccessibilityLabel: String {
        return isSelectionMode ? "Exit selection mode" : "Enter selection mode"
    }
    
    private var selectionModeAccessibilityHint: String {
        if isSelectionMode {
            return "Exits selection mode and returns to normal browsing"
        } else {
            return "Enters selection mode to select multiple favorites for batch operations"
        }
    }
    
    private var selectionModeAccessibilityValue: String {
        if isSelectionMode {
            return "Selection mode active, \(selectedImages.count) images selected"
        } else {
            return "Normal browsing mode"
        }
    }
}

/// Custom keyboard handler for favorites view navigation
class FavoritesKeyboardHandler: FavoritesKeyboardHandling {
    // Note: FavoritesView is a struct, so we don't need to store a reference to it
    let onNavigateLeft: () -> Void
    let onNavigateRight: () -> Void
    let onNavigateUp: () -> Void
    let onNavigateDown: () -> Void
    let onEnterFullScreen: () -> Void
    let onBackToFolderSelection: () -> Void
    let onToggleFavorite: () -> Void
    
    init(onNavigateLeft: @escaping () -> Void,
         onNavigateRight: @escaping () -> Void,
         onNavigateUp: @escaping () -> Void,
         onNavigateDown: @escaping () -> Void,
         onEnterFullScreen: @escaping () -> Void,
         onBackToFolderSelection: @escaping () -> Void,
         onToggleFavorite: @escaping () -> Void) {
        self.onNavigateLeft = onNavigateLeft
        self.onNavigateRight = onNavigateRight
        self.onNavigateUp = onNavigateUp
        self.onNavigateDown = onNavigateDown
        self.onEnterFullScreen = onEnterFullScreen
        self.onBackToFolderSelection = onBackToFolderSelection
        self.onToggleFavorite = onToggleFavorite
    }
    
    func handleKeyPress(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        
        // Handle arrow keys for navigation with accessibility announcements
        switch keyCode {
        case 123: // Left arrow
            onNavigateLeft()
            announceNavigationChange("Previous image")
            return true
            
        case 124: // Right arrow
            onNavigateRight()
            announceNavigationChange("Next image")
            return true
            
        case 125: // Down arrow
            onNavigateDown()
            announceNavigationChange("Image below")
            return true
            
        case 126: // Up arrow
            onNavigateUp()
            announceNavigationChange("Image above")
            return true
            
        case 36: // Enter/Return - enter full-screen
            onEnterFullScreen()
            announceAction("Entering full-screen view")
            return true
            
        case 53: // Escape - back to folder selection
            onBackToFolderSelection()
            announceAction("Returning to folder selection")
            return true
            
        case 49: // Spacebar - enter full-screen
            onEnterFullScreen()
            announceAction("Entering full-screen view")
            return true
            
        case 117: // Delete key - remove from favorites
            onToggleFavorite()
            announceAction("Removing from favorites")
            return true
            
        default:
            break
        }
        
        // Handle character keys
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }
        
        for character in characters {
            switch character {
            case "f":
                // Check if Cmd key is pressed for favorite toggle
                if modifierFlags.contains(.command) {
                    onToggleFavorite()
                    announceAction("Toggling favorite status")
                    return true
                } else {
                    onEnterFullScreen()
                    announceAction("Entering full-screen view")
                    return true
                }
                
            case "b":
                onBackToFolderSelection()
                announceAction("Returning to folder selection")
                return true
                
            case "s":
                // Toggle selection mode (accessibility shortcut)
                // This would need to be implemented in the parent view
                announceAction("Selection mode shortcut")
                return true
                
            default:
                continue
            }
        }
        
        return false
    }
    
    // MARK: - Accessibility Announcements
    
    private func announceNavigationChange(_ message: String) {
        // Post accessibility notification for navigation changes
        DispatchQueue.main.async {
            NSAccessibility.post(element: NSApp.mainWindow as Any, notification: NSAccessibility.Notification.announcementRequested)
        }
    }
    
    private func announceAction(_ message: String) {
        // Post accessibility notification for actions
        DispatchQueue.main.async {
            NSAccessibility.post(element: NSApp.mainWindow as Any, notification: NSAccessibility.Notification.announcementRequested)
        }
    }
}



// MARK: - Preview

#Preview {
    FavoritesView(
        onImageSelected: { _, _ in },
        onBackToFolderSelection: { }
    )
    .frame(width: 800, height: 600)
}
// swiftlint:disable file_length
import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    let windowStateManager: WindowStateManager
    @StateObject private var imageViewerViewModel = ImageViewerViewModel()
    @StateObject private var errorHandlingService = ErrorHandlingService.shared
    @StateObject private var folderPicker = FolderSelectionViewModel()
    @State private var showImageViewer = false
    @State private var restoredImageIndex: Int?
    @State private var restoringState: WindowState?
    @State private var restorationApplied = false
    @FocusState private var isStageFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Stage hover-arrow visibility (fade in on pointer move, out after ~3 s idle)
    @State private var stageArrowsVisible = false
    @State private var stageArrowsHideTask: Task<Void, Never>?

    // MARK: - Body
    var body: some View {
        observedContent
            .focusedSceneObject(imageViewerViewModel)
            .focusedSceneValue(\.openFolderAction, { openFolder() })
            .focusedSceneValue(\.backToFoldersAction, { returnToFolderSelection() })
            .focusedSceneValue(\.toggleSubfoldersAction, {
                folderPicker.setIncludeSubfolders(!folderPicker.includeSubfolders)
            })
            .focusedSceneValue(\.refreshFolderAction, { folderPicker.refreshCurrentFolder() })
    }

    private var observedContent: some View {
        mainContent
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(alignment: .topTrailing) {
                notificationOverlay
            }
            .overlay {
                modalErrorOverlay
            }
            .overlay {
                permissionRequestOverlay
            }
            .onAppear {
                setupApplication()
            }
            .onReceive(folderPicker.$selectedFolderContent.compactMap { $0 }) { content in
                handleFolderSelection(content)
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestFolderSelection)) { _ in
                returnToFolderSelection()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFolderPanel)) { _ in
                openFolder()
            }
            .onChange(of: imageViewerViewModel.shouldNavigateToFolderSelection) { _, requested in
                if requested { returnToFolderSelection() }
            }
            .onChange(of: folderPicker.isScanning) { _, scanning in
                if scanning { imageViewerViewModel.stopSlideshow() } else if !imageViewerViewModel.isCollectionComplete {
                    restoringState = nil
                    restoredImageIndex = nil
                    imageViewerViewModel.restoreSelectedImage(path: nil)
                }
            }
            .onChange(of: folderPicker.currentError) { _, error in
                if error != nil { restoredImageIndex = nil }
            }
            .onReceive(NotificationCenter.default.publisher(for: .restoreWindowState)) { notification in
                handleWindowStateRestoration(notification)
            }
            .modifier(FolderErrorAlert(folderPicker: folderPicker))
            .background(InvisibleKeyCapture(
                keyHandler: KeyboardHandler(imageViewerViewModel: imageViewerViewModel),
                isEnabled: showImageViewer && imageViewerViewModel.totalImages > 0
                    && !folderPicker.isShowingFolderPicker
                    && folderPicker.currentError == nil && errorHandlingService.modalError == nil
                    && !errorHandlingService.showPermissionDialog
            ))
    }

    private struct FolderErrorAlert: ViewModifier {
        @ObservedObject var folderPicker: FolderSelectionViewModel
        func body(content: Content) -> some View {
            content
            .alert("Unable to Open Folder", isPresented: Binding(
                get: { folderPicker.currentError != nil },
                set: { if !$0 { folderPicker.clearError() } }
            ), presenting: folderPicker.currentError) { _ in
                Button("OK") { folderPicker.clearError() }
            } message: { error in
                Text([error.localizedDescription, error.recoverySuggestion].compactMap { $0 }.joined(separator: "\n\n"))
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { geometry in
            ZStack {
                if showImageViewer {
                    imageViewerInterface(geometry: geometry)
                        // Toolbar owns the (hidden) title-bar region
                        .ignoresSafeArea(edges: .top)
                } else {
                    folderSelectionInterface
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    @ViewBuilder
    private func imageViewerInterface(geometry: GeometryProxy) -> some View {
        // Studio workspace: full-width toolbar on top (per the mocks — the
        // inspector docks below it), then stage (or grid) + filmstrip with the
        // inspector on the right. The stage only resizes as the single
        // inspector open/close animation (finding U4).
        VStack(spacing: 0) {
            StudioToolbar(viewModel: imageViewerViewModel, folderPicker: folderPicker)

            if folderPicker.isScanning || imageViewerViewModel.isProjectingCollection {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(folderPicker.isScanning
                         ? "\(folderPicker.imageCount) images found · scanning…" : "Updating collection…")
                    Spacer()
                    if folderPicker.isScanning { Button("Cancel") { folderPicker.cancelScanning() } }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            if !imageViewerViewModel.isCollectionComplete && !folderPicker.isScanning {
                HStack {
                    Text("Scan stopped. Showing discovered images.")
                    Spacer()
                    Button("Refresh Folder") { folderPicker.refreshCurrentFolder() }
                }
                .font(.callout)
                .padding(10)
            }
            if !imageViewerViewModel.scanIssues.isEmpty {
                DisclosureGroup("Some folders could not be read (\(imageViewerViewModel.scanIssues.count))") {
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(Array(imageViewerViewModel.scanIssues.enumerated()), id: \.offset) { _, issue in
                                Text("\(imageViewerViewModel.relativePath(for: issue.folderURL)): \(issue.message)")
                                    .textSelection(.enabled)
                            }
                        }
                    }.frame(maxHeight: 100)
                    Button("Retry") { folderPicker.refreshCurrentFolder() }
                }
                .font(.callout)
                .padding(10)
                .focusedValue(\.viewerKeyboardFocus, .control)
            }

            HSplitView {
                if imageViewerViewModel.includeSubfolders && imageViewerViewModel.folderSidebarVisible {
                    FolderBrowserSidebar(viewModel: imageViewerViewModel)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                }
                viewerWorkspace
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.3),
                value: imageViewerViewModel.inspectorVisible
            )
        }
    }
    
    private var viewerWorkspace: some View {
        HStack(spacing: 0) {
        VStack(spacing: 0) {
            if imageViewerViewModel.totalImages == 0 {
                browsingEmptyState
            } else if imageViewerViewModel.viewMode == .grid {
                GridPane(viewModel: imageViewerViewModel)
            } else {
                ZStack {
                    EnhancedImageDisplayView(viewModel: imageViewerViewModel)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active:
                                stageArrowsVisible = true
                                scheduleStageArrowsHide()
                            case .ended:
                                stageArrowsVisible = false
                                stageArrowsHideTask?.cancel()
                            }
                        }
                    StageHoverArrows(
                        viewModel: imageViewerViewModel,
                        isVisible: stageArrowsVisible
                    )
                }

                if imageViewerViewModel.viewMode.showsFilmstrip {
                    FilmstripView(viewModel: imageViewerViewModel)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .focusable()
        .focusEffectDisabled()
        .focused($isStageFocused)
        .focusedValue(\.viewerKeyboardFocus, .viewer)
        .simultaneousGesture(TapGesture().onEnded { isStageFocused = true })

        if imageViewerViewModel.inspectorVisible {
            InspectorView(viewModel: imageViewerViewModel)
                .transition(.move(edge: .trailing))
        }
        }
    }

    @ViewBuilder
    private var folderSelectionInterface: some View {
        FolderSelectionView(viewModel: folderPicker)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var notificationOverlay: some View {
        if !errorHandlingService.notifications.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(errorHandlingService.notifications) { notification in
                    notificationItem(notification)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                Spacer()
            }
            .padding(.top, showImageViewer ? 60 : 20)
            .padding(.trailing, 20)
            .padding(.leading, 20)
            .allowsHitTesting(true)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Notifications")
        }
    }
    
    @ViewBuilder
    private func notificationItem(_ notification: NotificationItem) -> some View {
        HStack {
            Text(notification.message)
                .foregroundColor(.white)
                .padding(12)
                .background(notification.type.color.opacity(0.9))
                .cornerRadius(8)
                .lineLimit(3)
                .accessibilityHidden(true)
            Button("×") {
                errorHandlingService.removeNotification(notification)
            }
            .foregroundColor(.white)
            .padding(.leading, 4)
            .accessibilityLabel("Dismiss notification")
            .focusedValue(\.viewerKeyboardFocus, .control)
        }
        .frame(maxWidth: 400)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.type.accessibilityPrefix): \(notification.message)")
    }
    
    @ViewBuilder
    private var modalErrorOverlay: some View {
        if let modalError = errorHandlingService.modalError {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text(modalError.title)
                        .font(.headline)
                    Text(modalError.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Button("OK") {
                        errorHandlingService.clearModalError()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(maxWidth: 400)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }
    
    @ViewBuilder
    private var permissionRequestOverlay: some View {
        if errorHandlingService.showPermissionDialog,
           let permissionRequest = errorHandlingService.permissionRequest {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text(permissionRequest.title)
                        .font(.headline)
                    Text(permissionRequest.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Text(permissionRequest.explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        if let secondaryAction = permissionRequest.secondaryAction {
                            Button(secondaryAction.title) {
                                secondaryAction.action()
                                errorHandlingService.clearPermissionDialog()
                            }
                            .buttonStyle(.bordered)
                        }
                        Button(permissionRequest.primaryAction.title) {
                            permissionRequest.primaryAction.action()
                            errorHandlingService.clearPermissionDialog()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
                .frame(maxWidth: 450)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }

    // MARK: - Private Methods

    private func scheduleStageArrowsHide() {
        stageArrowsHideTask?.cancel()
        stageArrowsHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            stageArrowsVisible = false
        }
    }

    private func setupApplication() {
        imageViewerViewModel.enableAsynchronousBrowsing()
        restoreApplicationState()
        setupWindowStateManager()
    }
    
    private func restoreApplicationState() {
        let preferencesService = DefaultPreferencesService()
        
        // Restore other preferences
        imageViewerViewModel.showFileName = preferencesService.showFileName
        
        // Initialize AI Insights state based on preferences
        initializeAIInsightsOnLaunch()
    }
    
    /// Initialize AI Insights state on app launch based on preferences and saved state
    private func initializeAIInsightsOnLaunch() {
        // Ensure AI Insights availability is properly set
        imageViewerViewModel.updateAIInsightsAvailability()
        
        // The actual panel visibility will be restored later when window state is applied
        // This ensures proper initialization order
        Logger.info("AI Insights initialization completed on app launch")
    }
    
    private func setupWindowStateManager() {
        // SwiftUI installs its own NSApplication delegate bridge; use the adaptor-owned manager directly.
        windowStateManager.setImageViewerViewModel(imageViewerViewModel)
    }
    
    private func returnToFolderSelection() {
        folderPicker.cancelScanning(keepingPartialResults: false)
        imageViewerViewModel.cancelImageInsightGeneration()
        imageViewerViewModel.cancelImageTextExtraction()
        restoredImageIndex = nil
        restoringState = nil
        imageViewerViewModel.stopSlideshow()
        imageViewerViewModel.shouldNavigateToFolderSelection = false
        showImageViewer = false
    }

    private func openFolder() {
        restoringState = nil
        restoredImageIndex = nil
        restorationApplied = false
        imageViewerViewModel.restoreSelectedImage(path: nil)
        folderPicker.selectFolder()
    }

    private func handleFolderSelection(_ content: FolderContent) {
        if let state = restoringState,
           state.lastFolderPath.map({ URL(fileURLWithPath: $0).standardizedFileURL.path })
                != content.folderURL.standardizedFileURL.path {
            restoringState = nil
            restoredImageIndex = nil
        }
        imageViewerViewModel.shouldNavigateToFolderSelection = false
        imageViewerViewModel.loadFolderContent(content.withCurrentIndex(restoredImageIndex ?? content.currentIndex))
        if let state = restoringState, !restorationApplied {
            state.applyUIState(to: imageViewerViewModel)
            imageViewerViewModel.restoreSelectedImage(path: state.restoredSelectedImageURL?.path)
            restorationApplied = true
        }
        if content.isComplete {
            restoredImageIndex = nil
            restoringState = nil
        }
        showImageViewer = true

        windowStateManager.updateFolderState(
            folderURL: content.folderURL,
            imageIndex: imageViewerViewModel.currentIndex
        )
    }

    private func handleWindowStateRestoration(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let folderURL = userInfo["folderURL"] as? URL,
              let imageIndex = userInfo["imageIndex"] as? Int else {
            return
        }
        restoredImageIndex = imageIndex
        restorationApplied = false
        restoringState = windowStateManager.currentWindowState
        folderPicker.restoreLastFolder(folderURL, includeSubfolders: restoringState?.includeSubfolders ?? false)
    }

    private var browsingEmptyState: some View {
        ContentUnavailableView {
            Label(emptyBrowsingTitle, systemImage: "photo.on.rectangle")
        } description: {
            Text(folderPicker.isScanning ? "Images will appear as they are found." : "Choose another folder or adjust the browsing scope.")
        } actions: {
            if imageViewerViewModel.filteredFolderURL != nil || !imageViewerViewModel.browserSearchText.isEmpty {
                Button("Clear Filter") { imageViewerViewModel.clearBrowsingFilter() }
            } else if !imageViewerViewModel.includeSubfolders {
                Button("Include Subfolders") { folderPicker.setIncludeSubfolders(true) }
            }
            Button("Choose Folder…") { folderPicker.selectFolder() }
        }
        .focusedValue(\.viewerKeyboardFocus, .control)
    }

    private var emptyBrowsingTitle: String {
        if folderPicker.isScanning { return "Finding images…" }
        if imageViewerViewModel.filteredFolderURL != nil || !imageViewerViewModel.browserSearchText.isEmpty {
            return "No matching images"
        }
        return imageViewerViewModel.includeSubfolders ? "No images in this folder tree" : "No images in this folder"
    }

}

private struct FolderBrowserNode: Identifiable {
    let url: URL
    let children: [FolderBrowserNode]?
    var id: URL { url }
}

private struct FolderBrowserSidebar: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @FocusState private var focusedControl: SidebarFocus?

    private enum SidebarFocus: Hashable {
        case search
        case folders
    }

    private var tree: [FolderBrowserNode] {
        guard let root = viewModel.currentFolderURL else { return [] }
        let folders = Set(viewModel.discoveredFolders).filter { $0 != root }
        let grouped = Dictionary(grouping: folders) { $0.deletingLastPathComponent() }
        func children(of parent: URL) -> [FolderBrowserNode] {
            (grouped[parent] ?? []).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                .map { url in
                    let descendants = children(of: url)
                    return FolderBrowserNode(url: url, children: descendants.isEmpty ? nil : descendants)
                }
        }
        return children(of: root)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Filter images…", text: $viewModel.browserSearchText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedControl, equals: .search)
                .focusedValue(\.viewerKeyboardFocus, .textInput)
                .accessibilityLabel("Filter by filename or relative folder path")
                .padding(10)
            List(selection: Binding(
                get: { viewModel.filteredFolderURL ?? viewModel.currentFolderURL },
                set: { folderURL in
                    // Establish list focus before projection can replace the selected grid tile.
                    focusedControl = .folders
                    viewModel.filteredFolderURL = folderURL == viewModel.currentFolderURL ? nil : folderURL
                }
            )) {
                if let root = viewModel.currentFolderURL {
                    Label("All images (\(viewModel.discoveredImageCount))", systemImage: "photo.on.rectangle")
                        .tag(root)
                }
                OutlineGroup(tree, children: \.children) { node in
                    HStack {
                        Label(node.url.lastPathComponent, systemImage: "folder")
                        Spacer()
                        Text("\(viewModel.folderImageCounts[node.url, default: 0])")
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    .tag(node.url)
                    .help("\(viewModel.relativePath(for: node.url)) and its subfolders")
                    .accessibilityLabel("\(viewModel.relativePath(for: node.url)), \(viewModel.folderImageCounts[node.url, default: 0]) images including subfolders")
                }
            }
            .listStyle(.sidebar)
            .focused($focusedControl, equals: .folders)
            .focusedValue(\.viewerKeyboardFocus, .control)
            .simultaneousGesture(TapGesture().onEnded { focusedControl = .folders })
            .accessibilityLabel("Folders")
        }
        .focusedValue(\.viewerKeyboardFocus, .control)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let folderSelected = Notification.Name("folderSelected")
}

// MARK: - Stage Hover Arrows

/// Prev/next arrows shown over the stage while the pointer is active (Studio
/// redesign). Purely presentational — hover tracking lives on the stage view
/// so this overlay never intercepts stage gestures. The far-side arrow — the
/// direction you can't navigate — idles at 35 % opacity.
private struct StageHoverArrows: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var viewModel: ImageViewerViewModel
    let isVisible: Bool

    var body: some View {
        HStack {
            arrow(symbol: "chevron.left", enabled: viewModel.hasPrevious, label: "Previous image") {
                viewModel.previousImage()
            }
            Spacer()
            arrow(symbol: "chevron.right", enabled: viewModel.hasNext, label: "Next image") {
                viewModel.nextImage()
            }
        }
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isVisible)
        .allowsHitTesting(isVisible)
    }

    private func arrow(symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(.sRGB, red: 20 / 255, green: 20 / 255, blue: 22 / 255, opacity: 0.7))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.35)
        .accessibilityLabel(label)
        .focusedValue(\.viewerKeyboardFocus, .control)
    }
}



// MARK: - Preview
#Preview {
    ContentView(windowStateManager: WindowStateManager())
        .frame(width: 1000, height: 700)
}

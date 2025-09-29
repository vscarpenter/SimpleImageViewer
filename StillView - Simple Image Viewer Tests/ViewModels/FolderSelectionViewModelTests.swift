import XCTest
import Combine
@testable import Simple_Image_Viewer

@MainActor
final class FolderSelectionViewModelTests: XCTestCase {
    
    var viewModel: FolderSelectionViewModel!
    var mockFileSystemService: MockFileSystemService!
    var mockPreferencesService: MockPreferencesService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockFileSystemService = MockFileSystemService()
        mockPreferencesService = MockPreferencesService()
        viewModel = FolderSelectionViewModel(
            fileSystemService: mockFileSystemService,
            preferencesService: mockPreferencesService
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockPreferencesService = nil
        mockFileSystemService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNil(viewModel.selectedFolderURL)
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertEqual(viewModel.scanProgress, 0.0)
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.isShowingFolderPicker)
        XCTAssertEqual(viewModel.imageCount, 0)
    }
    
    func testInitializationLoadsRecentFolders() {
        let testFolders = [
            URL(fileURLWithPath: "/Users/test/Pictures"),
            URL(fileURLWithPath: "/Users/test/Documents")
        ]
        mockPreferencesService.recentFolders = testFolders
        
        let newViewModel = FolderSelectionViewModel(
            fileSystemService: mockFileSystemService,
            preferencesService: mockPreferencesService
        )
        
        XCTAssertEqual(newViewModel.recentFolders, testFolders)
    }
    
    // MARK: - Folder Selection Tests
    
    func testSelectRecentFolderSuccess() async {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        let testImages = [
            createMockImageFile(name: "test1.jpg"),
            createMockImageFile(name: "test2.png")
        ]
        
        mockFileSystemService.scanFolderResult = .success(testImages)
        
        let expectation = XCTestExpectation(description: "Folder scanning completes")
        
        viewModel.$isScanning
            .dropFirst() // Skip initial false value
            .sink { isScanning in
                if !isScanning {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.selectRecentFolder(testURL)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertEqual(viewModel.selectedFolderURL, testURL)
        XCTAssertEqual(viewModel.imageCount, 2)
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertNil(viewModel.currentError)
        XCTAssertTrue(mockPreferencesService.addRecentFolderCalled)
        XCTAssertEqual(mockPreferencesService.lastSelectedFolder, testURL)
    }
    
    func testSelectRecentFolderNotFound() {
        let testURL = URL(fileURLWithPath: "/nonexistent/folder")
        
        viewModel.selectRecentFolder(testURL)
        
        XCTAssertNil(viewModel.selectedFolderURL)
        XCTAssertEqual(viewModel.currentError, .folderNotFound(testURL))
        XCTAssertTrue(mockPreferencesService.removeRecentFolderCalled)
    }
    
    func testSelectRecentFolderScanningError() async {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        let testError = FileSystemError.noImagesFound
        
        mockFileSystemService.scanFolderResult = .failure(testError)
        
        let expectation = XCTestExpectation(description: "Folder scanning fails")
        
        viewModel.$currentError
            .compactMap { $0 }
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.selectRecentFolder(testURL)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertEqual(viewModel.selectedFolderURL, testURL)
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertEqual(viewModel.imageCount, 0)
        XCTAssertEqual(viewModel.currentError, .noImagesFound)
    }
    
    // MARK: - Recent Folders Management Tests
    
    func testRemoveRecentFolder() {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        mockPreferencesService.recentFolders = [testURL]
        
        viewModel.removeRecentFolder(testURL)
        
        XCTAssertTrue(mockPreferencesService.removeRecentFolderCalled)
        XCTAssertEqual(mockPreferencesService.removedFolderURL, testURL)
    }
    
    func testClearRecentFolders() {
        viewModel.clearRecentFolders()
        
        XCTAssertTrue(mockPreferencesService.clearRecentFoldersCalled)
    }
    
    // MARK: - Scanning Control Tests
    
    func testCancelScanning() async {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        
        // Set up a delayed response to simulate long scanning
        mockFileSystemService.scanFolderDelay = 1.0
        mockFileSystemService.scanFolderResult = .success([])
        
        viewModel.selectRecentFolder(testURL)
        
        // Wait a bit for scanning to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(viewModel.isScanning)
        
        viewModel.cancelScanning()
        
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertEqual(viewModel.scanProgress, 0.0)
    }
    
    func testRefreshCurrentFolder() async {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        let testImages = [createMockImageFile(name: "test.jpg")]
        
        mockFileSystemService.scanFolderResult = .success(testImages)
        
        // First select a folder
        viewModel.selectRecentFolder(testURL)
        
        let expectation = XCTestExpectation(description: "First scan completes")
        
        viewModel.$isScanning
            .dropFirst()
            .sink { isScanning in
                if !isScanning {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Reset scan call count
        mockFileSystemService.scanFolderCallCount = 0
        
        // Now refresh
        let refreshExpectation = XCTestExpectation(description: "Refresh scan completes")
        
        viewModel.$isScanning
            .dropFirst()
            .sink { isScanning in
                if !isScanning {
                    refreshExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.refreshCurrentFolder()
        
        await fulfillment(of: [refreshExpectation], timeout: 2.0)
        
        XCTAssertEqual(mockFileSystemService.scanFolderCallCount, 1)
    }
    
    func testRefreshCurrentFolderWithNoSelection() {
        viewModel.refreshCurrentFolder()
        
        XCTAssertEqual(mockFileSystemService.scanFolderCallCount, 0)
        XCTAssertFalse(viewModel.isScanning)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError() {
        viewModel.currentError = .noImagesFound
        
        viewModel.clearError()
        
        XCTAssertNil(viewModel.currentError)
    }
    
    func testScanProgressTracking() async {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        let testImages = [createMockImageFile(name: "test.jpg")]
        
        mockFileSystemService.scanFolderResult = .success(testImages)
        
        let progressExpectation = XCTestExpectation(description: "Progress updates")
        var progressValues: [Double] = []
        
        viewModel.$scanProgress
            .sink { progress in
                progressValues.append(progress)
                if progress == 1.0 {
                    progressExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.selectRecentFolder(testURL)
        
        await fulfillment(of: [progressExpectation], timeout: 2.0)
        
        XCTAssertTrue(progressValues.contains(0.0)) // Initial value
        XCTAssertTrue(progressValues.contains(0.1)) // Scanning started
        XCTAssertTrue(progressValues.contains(1.0)) // Scanning completed
    }
    
    // MARK: - Notification Tests
    
    func testFolderScanCompletedNotification() async {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        let testImages = [createMockImageFile(name: "test.jpg")]
        
        mockFileSystemService.scanFolderResult = .success(testImages)
        
        let notificationExpectation = XCTestExpectation(description: "Notification posted")
        
        NotificationCenter.default.publisher(for: .folderScanCompleted)
            .sink { notification in
                XCTAssertEqual(notification.userInfo?["folderURL"] as? URL, testURL)
                XCTAssertEqual((notification.userInfo?["imageFiles"] as? [ImageFile])?.count, 1)
                notificationExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.selectRecentFolder(testURL)
        
        await fulfillment(of: [notificationExpectation], timeout: 2.0)
    }
    
    func testFolderScanFailedNotification() async {
        let testURL = URL(fileURLWithPath: "/Users/test/Pictures")
        let testError = FileSystemError.noImagesFound
        
        mockFileSystemService.scanFolderResult = .failure(testError)
        
        let notificationExpectation = XCTestExpectation(description: "Notification posted")
        
        NotificationCenter.default.publisher(for: .folderScanFailed)
            .sink { notification in
                XCTAssertEqual(notification.userInfo?["folderURL"] as? URL, testURL)
                XCTAssertNotNil(notification.userInfo?["error"])
                notificationExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.selectRecentFolder(testURL)
        
        await fulfillment(of: [notificationExpectation], timeout: 2.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockImageFile(name: String) -> ImageFile {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        return try! ImageFile(url: url)
    }
}

// MARK: - Mock Services

class MockFileSystemService: FileSystemService {
    var scanFolderResult: Result<[ImageFile], Error> = .success([])
    var scanFolderCallCount = 0
    var scanFolderDelay: TimeInterval = 0
    var createBookmarkResult: Data? = Data()
    var resolveBookmarkResult: URL?
    var isSupportedResult = true
    var fileTypeResult: UTType? = .jpeg
    
    func scanFolder(_ url: URL, recursive: Bool) async throws -> [ImageFile] {
        scanFolderCallCount += 1
        
        if scanFolderDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(scanFolderDelay * 1_000_000_000))
        }
        
        switch scanFolderResult {
        case .success(let files):
            return files
        case .failure(let error):
            throw error
        }
    }
    
    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never> {
        return Empty<[ImageFile], Never>().eraseToAnyPublisher()
    }
    
    func createSecurityScopedBookmark(for url: URL) -> Data? {
        return createBookmarkResult
    }
    
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL? {
        return resolveBookmarkResult
    }
    
    func isSupportedImageFile(_ url: URL) -> Bool {
        return isSupportedResult
    }
    
    func getFileType(for url: URL) -> UTType? {
        return fileTypeResult
    }
}

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = .zero
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout: Bool = true
    var enableAIAnalysis: Bool = true
    
    var addRecentFolderCalled = false
    var removeRecentFolderCalled = false
    var removedFolderURL: URL?
    var clearRecentFoldersCalled = false
    var savePreferencesCalled = false
    var loadPreferencesCalled = false
    
    func addRecentFolder(_ url: URL) {
        addRecentFolderCalled = true
        recentFolders.insert(url, at: 0)
        if recentFolders.count > 10 {
            recentFolders = Array(recentFolders.prefix(10))
        }
    }
    
    func removeRecentFolder(_ url: URL) {
        removeRecentFolderCalled = true
        removedFolderURL = url
        recentFolders.removeAll { $0 == url }
    }
    
    func clearRecentFolders() {
        clearRecentFoldersCalled = true
        recentFolders = []
        folderBookmarks = []
    }
    
    func savePreferences() {
        savePreferencesCalled = true
    }
    
    func loadPreferences() {
        loadPreferencesCalled = true
    }

    func saveWindowState(_ windowState: WindowState) {
        self.windowState = windowState
    }

    func loadWindowState() -> WindowState? {
        return windowState
    }

    func saveFavorites() { }
}

import XCTest
import Combine
import Darwin
import UniformTypeIdentifiers
@testable import StillView___Simple_Image_Viewer

final class FileSystemServiceTests: XCTestCase {
    var fileSystemService: DefaultFileSystemService!
    var tempDirectory: URL!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileSystemService = DefaultFileSystemService()
        cancellables = Set<AnyCancellable>()

        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Clean up temporary directory
        cancellables = nil
        fileSystemService = nil
        if let tempDirectory, FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helper Methods

    private func createTestImageFile(name: String, extension: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent("\(name).\(`extension`)")

        // Scanning uses file metadata and does not decode image contents.
        // Header-only fixtures exercise discovery without promising decodability.
        var data: Data
        switch `extension`.lowercased() {
        case "jpg", "jpeg":
            // Minimal JPEG header
            data = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
        case "png":
            // PNG signature
            data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "gif":
            // GIF header
            data = Data("GIF89a".utf8)
        default:
            // Generic binary data
            data = Data([0x00, 0x01, 0x02, 0x03])
        }

        try data.write(to: fileURL)
        return fileURL
    }

    private func createTestTextFile(name: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent("\(name).txt")
        try "Test content".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func createSubdirectory(name: String) throws -> URL {
        let subdirURL = tempDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: subdirURL, withIntermediateDirectories: true)
        return subdirURL
    }

    // MARK: - Folder Scanning Tests

    func testScanEmptyFolder() async {
        do {
            let result = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTFail("Expected FileSystemError.noImagesFound, but got \(result)")
        } catch FileSystemError.noImagesFound {
            // Expected behavior
        } catch {
            XCTFail("Expected FileSystemError.noImagesFound, but got \(error)")
        }
    }

    func testScanFolderWithImages() async throws {
        // Create test image files
        _ = try createTestImageFile(name: "image1", extension: "jpg")
        _ = try createTestImageFile(name: "image2", extension: "png")
        _ = try createTestImageFile(name: "image10", extension: "gif")

        do {
            let result = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTAssertEqual(result.count, 3)

            // Natural ordering keeps image2 before image10.
            XCTAssertEqual(result[0].name, "image1.jpg")
            XCTAssertEqual(result[1].name, "image2.png")
            XCTAssertEqual(result[2].name, "image10.gif")

            // Verify file types
            XCTAssertTrue(result[0].type.conforms(to: .jpeg))
            XCTAssertTrue(result[1].type.conforms(to: .png))
            XCTAssertTrue(result[2].type.conforms(to: .gif))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testScanFolderWithMixedFiles() async throws {
        // Create mix of image and non-image files
        _ = try createTestImageFile(name: "image1", extension: "jpg")
        _ = try createTestTextFile(name: "document1")
        _ = try createTestImageFile(name: "image2", extension: "png")

        do {
            let result = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTAssertEqual(result.count, 2) // Only image files should be included
            XCTAssertEqual(result[0].name, "image1.jpg")
            XCTAssertEqual(result[1].name, "image2.png")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_scanFolder_skipsHiddenFilesAndImageNamedDirectories() async throws {
        _ = try createTestImageFile(name: "visible", extension: "jpg")
        _ = try createTestImageFile(name: ".hidden", extension: "png")
        _ = try createSubdirectory(name: "album.jpg")

        let files = try await fileSystemService.scanFolder(tempDirectory, recursive: false)

        XCTAssertEqual(files.map(\.name), ["visible.jpg"])
    }

    func testScanFolderRecursive() async throws {
        // Create images in root directory
        _ = try createTestImageFile(name: "root_image", extension: "jpg")

        // Create subdirectory with images
        let subdir = try createSubdirectory(name: "subdir")
        let subdirImageURL = subdir.appendingPathComponent("sub_image.png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: subdirImageURL)

        do {
            // Test non-recursive scan
            let shallowResult = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTAssertEqual(shallowResult.count, 1)
            XCTAssertEqual(shallowResult[0].name, "root_image.jpg")

            // Test recursive scan
            let recursiveResult = try await fileSystemService.scanFolder(tempDirectory, recursive: true)
            XCTAssertEqual(recursiveResult.count, 2)

            // Results should be sorted by name
            let sortedNames = recursiveResult.map { $0.name }.sorted()
            XCTAssertEqual(sortedNames, ["root_image.jpg", "sub_image.png"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testScanNonExistentFolder() async {
        let nonExistentURL = tempDirectory.appendingPathComponent("nonexistent", isDirectory: true)

        do {
            _ = try await fileSystemService.scanFolder(nonExistentURL, recursive: false)
            XCTFail("Expected FileSystemError.folderNotFound")
        } catch FileSystemError.folderNotFound {
            // Expected behavior
        } catch {
            XCTFail("Expected FileSystemError.folderNotFound, but got \(error)")
        }
    }

    func test_scanFolder_recursiveSkipsPackagesHiddenFoldersAndLinks() async throws {
        let visible = try createTestImageFile(name: "visible", extension: "jpg")
        let nested = try createSubdirectory(name: "album")
        let child = nested.appendingPathComponent("child.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: child)
        let package = try createSubdirectory(name: "Sample.app/Contents/Resources")
        try Data([0xFF, 0xD8]).write(to: package.appendingPathComponent("excluded.jpg"))
        let hidden = try createSubdirectory(name: ".hidden")
        try Data([0xFF, 0xD8]).write(to: hidden.appendingPathComponent("excluded.jpg"))
        try FileManager.default.createSymbolicLink(
            at: tempDirectory.appendingPathComponent("linked.jpg"), withDestinationURL: visible
        )
        try FileManager.default.createSymbolicLink(
            at: nested.appendingPathComponent("cycle", isDirectory: true), withDestinationURL: tempDirectory
        )

        let images = try await fileSystemService.scanFolder(tempDirectory, recursive: true)

        XCTAssertEqual(Set(images.map(\.url)), Set([visible, child]))
    }

    func test_scanFolder_preCanceledTaskDoesNotCompleteDiscovery() async throws {
        _ = try createTestImageFile(name: "visible", extension: "jpg")
        let service = try XCTUnwrap(fileSystemService)
        let root = try XCTUnwrap(tempDirectory)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.scanFolder(root, recursive: true)
        }

        do {
            _ = try await task.value
            XCTFail("A pre-canceled scan must throw CancellationError")
        } catch is CancellationError {
            // Expected: cancellation must remain distinguishable from an empty folder.
        }
    }

    func test_scanFolder_duplicateNamesUseDeterministicPathTieBreaker() async throws {
        let lastFolder = try createSubdirectory(name: "z-last")
        let firstFolder = try createSubdirectory(name: "a-first")
        let last = lastFolder.appendingPathComponent("same.jpg")
        let first = firstFolder.appendingPathComponent("same.jpg")
        try Data([0xFF, 0xD8]).write(to: last)
        try Data([0xFF, 0xD8]).write(to: first)

        let images = try await fileSystemService.scanFolder(tempDirectory, recursive: true)

        XCTAssertEqual(images.map(\.url), [first, last])
    }

    func testScanFileInsteadOfFolder() async throws {
        let fileURL = try createTestImageFile(name: "test", extension: "jpg")

        do {
            _ = try await fileSystemService.scanFolder(fileURL, recursive: false)
            XCTFail("Expected FileSystemError.folderNotFound")
        } catch FileSystemError.folderNotFound {
            // Expected behavior
        } catch {
            XCTFail("Expected FileSystemError.folderNotFound, but got \(error)")
        }
    }

    // MARK: - File Type Detection Tests

    func testIsSupportedImageFile() throws {
        let jpegURL = try createTestImageFile(name: "test", extension: "jpg")
        let pngURL = try createTestImageFile(name: "test", extension: "png")
        let textURL = try createTestTextFile(name: "test")

        XCTAssertTrue(fileSystemService.isSupportedImageFile(jpegURL))
        XCTAssertTrue(fileSystemService.isSupportedImageFile(pngURL))
        XCTAssertFalse(fileSystemService.isSupportedImageFile(textURL))
    }

    func testGetFileType() throws {
        let jpegURL = try createTestImageFile(name: "test", extension: "jpg")
        let pngURL = try createTestImageFile(name: "test", extension: "png")

        let jpegType = fileSystemService.getFileType(for: jpegURL)
        let pngType = fileSystemService.getFileType(for: pngURL)

        XCTAssertNotNil(jpegType)
        XCTAssertNotNil(pngType)
        XCTAssertTrue(jpegType?.conforms(to: .jpeg) ?? false)
        XCTAssertTrue(pngType?.conforms(to: .png) ?? false)
    }

    // MARK: - Security-Scoped Bookmark Tests

    func testCreateSecurityScopedBookmark() {
        let bookmarkData = fileSystemService.createSecurityScopedBookmark(for: tempDirectory)
        XCTAssertNotNil(bookmarkData)
        XCTAssertFalse(bookmarkData?.isEmpty ?? true)
    }

    func testCreatedBookmarkRefersToOriginalFolder() throws {
        let bookmarkData = try XCTUnwrap(fileSystemService.createSecurityScopedBookmark(for: tempDirectory))
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        XCTAssertFalse(isStale)
        XCTAssertEqual(resolvedURL.standardizedFileURL, tempDirectory.standardizedFileURL)
        // A temporary directory is already accessible to the test host. It cannot
        // establish whether a user-granted security scope can be activated.
    }

    func testResolveInvalidBookmark() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(invalidData)
        XCTAssertNil(resolvedURL)
    }

    // MARK: - Folder Monitoring Tests

    func testFolderMonitoring() throws {
        let update = expectation(description: "Folder monitoring detects the added image")

        fileSystemService.monitorFolder(tempDirectory)
            .filter { $0.contains { $0.name == "monitored.jpg" } }
            .prefix(1)
            .sink { files in
                XCTAssertEqual(files.map(\.name), ["monitored.jpg"])
                update.fulfill()
            }
            .store(in: &cancellables)

        _ = try createTestImageFile(name: "monitored", extension: "jpg")
        wait(for: [update], timeout: 5)
    }

    func testMultipleFolderMonitoring() throws {
        let subdir = try createSubdirectory(name: "subdir")
        let rootUpdate = expectation(description: "Root folder detects its image")
        let subfolderUpdate = expectation(description: "Subfolder detects its image")

        fileSystemService.monitorFolder(tempDirectory)
            .filter { $0.contains { $0.name == "root.jpg" } }
            .prefix(1)
            .sink { files in
                XCTAssertEqual(files.map(\.name), ["root.jpg"])
                rootUpdate.fulfill()
            }
            .store(in: &cancellables)

        fileSystemService.monitorFolder(subdir)
            .filter { $0.contains { $0.name == "sub.png" } }
            .prefix(1)
            .sink { files in
                XCTAssertEqual(files.map(\.name), ["sub.png"])
                subfolderUpdate.fulfill()
            }
            .store(in: &cancellables)

        _ = try createTestImageFile(name: "root", extension: "jpg")
        let subdirImageURL = subdir.appendingPathComponent("sub.png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: subdirImageURL)

        wait(for: [rootUpdate, subfolderUpdate], timeout: 5)
    }
}

final class SecurityScopedAccessPathRegressionTests: XCTestCase {
    func test_currentFolder_acceptsSymlinkAliasWithoutReplacingScopedURL() throws {
        let fixture = try makeAliasFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let manager = SecurityScopedAccessManager()
        _ = manager.startAccess(for: fixture.alias)

        XCTAssertTrue(manager.hasAccess(to: fixture.image))
        XCTAssertEqual(manager.currentURL, fixture.alias, "Keep the original security-scoped URL alive")
    }

    func test_favoriteFolder_acceptsSymlinkAliasWithoutReplacingTrackedURL() throws {
        let fixture = try makeAliasFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let manager = SecurityScopedAccessManager()
        manager.addFavoriteFolder(fixture.alias)
        defer { manager.removeFavoriteFolder(fixture.alias) }

        XCTAssertTrue(manager.hasAccess(to: fixture.image))
        XCTAssertTrue(manager.trackedFavoriteFolders.contains(fixture.alias))
    }

    func test_pathComparison_treatsTmpAndPrivateTmpAsTheSameFolder() {
        let alias = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let canonical = URL(fileURLWithPath: "/private/tmp", isDirectory: true)

        XCTAssertTrue(SecurityScopedAccessManager.isSameOrDescendant(canonical, of: alias))
        XCTAssertTrue(SecurityScopedAccessManager.isSameOrDescendant(alias, of: canonical))
        XCTAssertTrue(SecurityScopedAccessManager.isSameOrDescendant(
            canonical.appendingPathComponent("image.png"), of: alias
        ))
    }

    func test_pathComparison_rejectsSiblingWithMatchingPrefix() throws {
        let fixture = try makeAliasFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let sibling = fixture.directory.appendingPathComponent("photos-other", isDirectory: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        let image = sibling.appendingPathComponent("image.png")
        try Data([1]).write(to: image)

        XCTAssertFalse(SecurityScopedAccessManager.isSameOrDescendant(image, of: fixture.root))
    }

    func test_pathComparison_rejectsSymlinkEscapingTheGrantedFolder() throws {
        let fixture = try makeAliasFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let outside = fixture.directory.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data([1]).write(to: outside.appendingPathComponent("image.png"))
        let escape = fixture.root.appendingPathComponent("escape", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: escape, withDestinationURL: outside)

        XCTAssertFalse(SecurityScopedAccessManager.isSameOrDescendant(
            escape.appendingPathComponent("image.png"), of: fixture.root
        ))
        XCTAssertFalse(SecurityScopedAccessManager.isSameOrDescendant(
            escape.appendingPathComponent("image.png"), of: fixture.alias
        ))
        XCTAssertFalse(SecurityScopedAccessManager.isSameOrDescendant(
            escape.appendingPathComponent("missing.png"), of: fixture.root
        ))
    }

    func test_pathComparison_rejectsNonFileURLs() throws {
        let root = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let remote = try XCTUnwrap(URL(string: "https://example.com/tmp/image.png"))

        XCTAssertFalse(SecurityScopedAccessManager.isSameOrDescendant(remote, of: root))
        XCTAssertFalse(SecurityScopedAccessManager.isSameOrDescendant(root, of: remote))
    }

    private func makeAliasFixture() throws -> (directory: URL, root: URL, alias: URL, image: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = directory.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let alias = directory.appendingPathComponent("selected-alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        let image = root.appendingPathComponent("image.png")
        try Data([1]).write(to: image)
        return (directory, root, alias, image)
    }
}

@MainActor
final class FolderPresentationRegressionTests: XCTestCase {
    func test_selectFolder_ignoresDuplicateRequestsWhilePanelIsOpen() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        fixture.model.selectFolder()
        fixture.model.selectFolder()

        XCTAssertTrue(fixture.model.isShowingFolderPicker)
        XCTAssertEqual(fixture.panel.presentationCount, 1)
        XCTAssertEqual(fixture.service.scanCount, 0)
        fixture.panel.complete(with: nil)
    }

    func test_cancelPicker_preservesCurrentFolderAndAccess() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        fixture.model.selectFolder()
        fixture.panel.complete(with: nil)

        XCTAssertFalse(fixture.model.isShowingFolderPicker)
        XCTAssertEqual(fixture.model.selectedFolderContent?.folderURL, fixture.original)
        XCTAssertEqual(fixture.model.selectedFolderURL, fixture.original)
        XCTAssertEqual(fixture.manager.currentURL, fixture.original)
        XCTAssertEqual(fixture.service.scanCount, 0)
    }

    func test_acceptPicker_keepsPreviousAccessUntilBatchAndPublishesCompletion() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        var publications: [FolderContent] = []
        let subscription = fixture.model.$selectedFolderContent.dropFirst().compactMap { $0 }
            .sink { publications.append($0) }
        defer { subscription.cancel() }

        fixture.model.selectFolder()
        fixture.panel.complete(with: fixture.candidate)
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)

        XCTAssertFalse(fixture.model.isShowingFolderPicker)
        XCTAssertTrue(fixture.model.isScanning)
        XCTAssertEqual(fixture.manager.currentURL, fixture.original)
        XCTAssertEqual(fixture.model.selectedFolderURL, fixture.original)
        let completed = expectation(description: "Successful scan publishes content")
        let completion = fixture.model.$isScanning.dropFirst().filter { !$0 }.prefix(1)
            .sink { _ in completed.fulfill() }
        fixture.service.complete(with: .success([makeImage(in: fixture.candidate)]))
        await fulfillment(of: [completed], timeout: 2)
        completion.cancel()

        XCTAssertEqual(fixture.service.scanCount, 1)
        XCTAssertEqual(publications.map(\.folderURL), [fixture.candidate, fixture.candidate])
        XCTAssertEqual(publications.map(\.isComplete), [false, true])
        XCTAssertEqual(publications.map(\.totalImages), [1, 1])
        XCTAssertEqual(fixture.model.selectedFolderContent?.folderURL, fixture.candidate)
        XCTAssertEqual(fixture.model.selectedFolderURL, fixture.candidate)
        XCTAssertEqual(fixture.manager.currentURL, fixture.candidate)
    }

    func test_failedScan_preservesCurrentFolderAndAccess() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.model.selectFolder()
        fixture.panel.complete(with: fixture.candidate)
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)
        let failed = expectation(description: "Scan exposes its error")
        let subscription = fixture.model.$currentError.compactMap { $0 }.prefix(1)
            .sink { _ in failed.fulfill() }
        fixture.service.complete(with: .failure(FileSystemError.folderAccessDenied))
        await fulfillment(of: [failed], timeout: 2)
        subscription.cancel()

        XCTAssertFalse(fixture.model.isScanning)
        XCTAssertNotNil(fixture.model.currentError)
        XCTAssertEqual(fixture.model.selectedFolderContent?.folderURL, fixture.original)
        XCTAssertEqual(fixture.model.selectedFolderURL, fixture.original)
        XCTAssertEqual(fixture.manager.currentURL, fixture.original)
    }

    func test_cancelScan_discardsLateResultAndPreservesCurrentFolder() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.model.selectFolder()
        fixture.panel.complete(with: fixture.candidate)
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)
        let replaced = expectation(description: "Canceled scan must not publish")
        replaced.isInverted = true
        let subscription = fixture.model.$selectedFolderContent.dropFirst()
            .sink { _ in replaced.fulfill() }

        fixture.model.cancelScanning()
        fixture.service.complete(with: .success([makeImage(in: fixture.candidate)]))
        await fulfillment(of: [replaced], timeout: 0.1)
        subscription.cancel()

        XCTAssertFalse(fixture.model.isScanning)
        XCTAssertEqual(fixture.model.selectedFolderContent?.folderURL, fixture.original)
        XCTAssertEqual(fixture.model.selectedFolderURL, fixture.original)
        XCTAssertEqual(fixture.manager.currentURL, fixture.original)
    }

    func test_expiredRecentBookmark_exposesOnlyTheFolderAlert() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let preferences = DefaultPreferencesService(userDefaults: fixture.defaults)
        preferences.recentFolders = [fixture.candidate]
        preferences.folderBookmarks = [Data([0x01])]
        preferences.savePreferences()
        let duplicateDialog = expectation(description: "Folder failure must not open a second permission dialog")
        duplicateDialog.isInverted = true
        let subscription = ErrorHandlingService.shared.$showPermissionDialog.dropFirst()
            .sink { _ in duplicateDialog.fulfill() }

        fixture.model.selectRecentFolder(fixture.candidate)
        await fulfillment(of: [duplicateDialog], timeout: 0.1)
        subscription.cancel()

        guard case .bookmarkResolutionFailed(let url) = fixture.model.currentError else {
            return XCTFail("Expected the central folder alert to receive the expired bookmark error")
        }
        XCTAssertEqual(url, fixture.candidate)
        XCTAssertEqual(fixture.manager.currentURL, fixture.original)
        XCTAssertEqual(fixture.service.scanCount, 0)
    }

    func test_movedRecentBookmark_updatesItsRecordBeforeScanAndPromotesWithoutDuplicate() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let moved = fixture.directory.appendingPathComponent("moved", isDirectory: true)
        try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: true)
        let preferences = DefaultPreferencesService(userDefaults: fixture.defaults)
        let bookmark = Data([0x42])
        let unrelated = RecentFolderRecord(url: fixture.original, bookmarkData: Data([0x10]))
        preferences.recentFolderRecords = [
            unrelated, RecentFolderRecord(url: fixture.candidate, bookmarkData: bookmark)
        ]
        fixture.service.resolvedBookmarkURL = moved

        fixture.model.selectRecentFolder(fixture.candidate)

        XCTAssertEqual(preferences.recentFolderRecords, [
            unrelated, RecentFolderRecord(url: moved, bookmarkData: bookmark)
        ], "A moved grant must update its existing slot before the scan can publish or fail")
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)
        let completed = expectation(description: "Moved folder scan completes")
        let subscription = fixture.model.$isScanning.dropFirst().filter { !$0 }.prefix(1)
            .sink { _ in completed.fulfill() }
        fixture.service.complete(with: .success([makeImage(in: moved)]))
        await fulfillment(of: [completed], timeout: 2)
        subscription.cancel()

        XCTAssertEqual(preferences.recentFolderRecords, [
            RecentFolderRecord(url: moved, bookmarkData: bookmark), unrelated
        ])
        XCTAssertFalse(preferences.recentFolders.contains(fixture.candidate))
        XCTAssertEqual(fixture.model.selectedFolderURL, moved)
        XCTAssertEqual(fixture.manager.currentURL, moved)
    }

    func test_movedRecentBookmark_replacesExistingDestinationRecordWithResolvedGrant() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let moved = fixture.directory.appendingPathComponent("moved", isDirectory: true)
        try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: true)
        let preferences = DefaultPreferencesService(userDefaults: fixture.defaults)
        let bookmark = Data([0x42])
        let unrelated = RecentFolderRecord(url: fixture.original, bookmarkData: Data([0x10]))
        preferences.recentFolderRecords = [
            RecentFolderRecord(url: moved, bookmarkData: Data([0x20])), unrelated,
            RecentFolderRecord(url: fixture.candidate, bookmarkData: bookmark)
        ]
        fixture.service.resolvedBookmarkURL = moved

        fixture.model.selectRecentFolder(fixture.candidate)

        XCTAssertEqual(preferences.recentFolderRecords, [
            unrelated, RecentFolderRecord(url: moved, bookmarkData: bookmark)
        ])
    }

    func test_invalidRecentSelection_cancelsEarlierScanBeforeItsLateResult() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.model.selectFolder()
        fixture.panel.complete(with: fixture.candidate)
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)
        let replaced = expectation(description: "Earlier scan must not replace a failed later selection")
        replaced.isInverted = true
        let subscription = fixture.model.$selectedFolderContent.dropFirst()
            .sink { _ in replaced.fulfill() }
        let missing = fixture.directory.appendingPathComponent("missing", isDirectory: true)

        fixture.model.selectRecentFolder(missing)
        fixture.service.complete(with: .success([makeImage(in: fixture.candidate)]))
        await fulfillment(of: [replaced], timeout: 0.1)
        subscription.cancel()

        XCTAssertFalse(fixture.model.isScanning)
        guard case .folderNotFound(let url) = fixture.model.currentError else {
            return XCTFail("Expected the later missing-folder error to remain visible")
        }
        XCTAssertEqual(url, missing)
        XCTAssertEqual(fixture.model.selectedFolderContent?.folderURL, fixture.original)
        XCTAssertEqual(fixture.model.selectedFolderURL, fixture.original)
        XCTAssertEqual(fixture.manager.currentURL, fixture.original)
    }

    private func makeImage(in folder: URL) -> ImageFile {
        ImageFile(url: folder.appendingPathComponent("sample.jpg"), name: "sample.jpg", type: .jpeg,
                  size: 10, creationDate: .distantPast, modificationDate: .distantPast)
    }

    private func makeFixture() throws -> FolderPresentationFixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let original = directory.appendingPathComponent("original", isDirectory: true)
        let candidate = directory.appendingPathComponent("candidate", isDirectory: true)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
        let suite = "FolderPresentationRegressionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let panel = ControlledFolderPanelPresenter()
        let service = ControlledFolderScanService()
        let manager = SecurityScopedAccessManager()
        let model = FolderSelectionViewModel(
            fileSystemService: service,
            preferencesService: DefaultPreferencesService(userDefaults: defaults),
            panelPresenter: panel,
            accessManager: manager
        )
        model.selectedFolderURL = original
        model.selectedFolderContent = FolderContent(folderURL: original, imageFiles: [makeImage(in: original)])
        _ = manager.startAccess(for: original)
        return FolderPresentationFixture(
            model: model, panel: panel, service: service, manager: manager,
            original: original, candidate: candidate, directory: directory, defaults: defaults, suite: suite
        )
    }
}

@MainActor
private struct FolderPresentationFixture {
    let model: FolderSelectionViewModel
    let panel: ControlledFolderPanelPresenter
    let service: ControlledFolderScanService
    let manager: SecurityScopedAccessManager
    let original: URL
    let candidate: URL
    let directory: URL
    let defaults: UserDefaults
    let suite: String

    func cleanup() {
        model.cancelScanning()
        manager.stopCurrentAccess()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class ControlledFolderPanelPresenter: FolderPanelPresenting {
    private(set) var presentationCount = 0
    private var completion: (@MainActor (URL?) -> Void)?

    func present(initialDirectory: URL?, completion: @escaping @MainActor (URL?) -> Void) {
        presentationCount += 1
        self.completion = completion
    }

    func complete(with url: URL?) {
        let callback = completion
        completion = nil
        callback?(url)
    }
}

private final class ControlledFolderScanService: FileSystemService, @unchecked Sendable {
    let scanStarted = XCTestExpectation(description: "Folder scan started")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[ImageFile], Error>?
    private var requests = 0
    var resolvedBookmarkURL: URL?

    var scanCount: Int { lock.withLock { requests } }

    func scanFolder(_ url: URL, recursive: Bool) async throws -> [ImageFile] {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                requests += 1
                self.continuation = continuation
            }
            scanStarted.fulfill()
        }
    }

    func complete(with result: Result<[ImageFile], Error>) {
        let pending = lock.withLock {
            let pending = continuation
            continuation = nil
            return pending
        }
        pending?.resume(with: result)
    }

    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never> { Empty().eraseToAnyPublisher() }
    func createSecurityScopedBookmark(for url: URL) -> Data? { nil }
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL? { resolvedBookmarkURL }
    func isSupportedImageFile(_ url: URL) -> Bool { true }
    func getFileType(for url: URL) -> UTType? { .jpeg }
}

final class RecursiveFolderScanTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func test_scanEvents_emptyRootCompletesWithFolderRecord() async throws {
        var folders: [URL] = []
        var images: [ImageFile] = []
        for try await event in DefaultFileSystemService().scanEvents(root, recursive: true) {
            if case .batch(let batch, let discovered) = event {
                images.append(contentsOf: batch)
                folders.append(contentsOf: discovered)
            }
        }

        XCTAssertTrue(images.isEmpty)
        XCTAssertEqual(folders, [root])
    }

    func test_scanEvents_boundedBatchesIncludeEveryFileAndEmptyDescendantFolder() async throws {
        let nested = root.appendingPathComponent("album/empty", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        for index in 0..<145 {
            try Data([0xFF, 0xD8]).write(to: root.appendingPathComponent("image\(index).jpg"))
        }
        var images: [ImageFile] = []
        var folders: [URL] = []
        var batchCount = 0
        for try await event in DefaultFileSystemService().scanEvents(root, recursive: true) {
            if case .batch(let batch, let discovered) = event {
                XCTAssertLessThanOrEqual(batch.count + discovered.count, 64)
                images.append(contentsOf: batch)
                folders.append(contentsOf: discovered)
                batchCount += 1
            }
        }

        XCTAssertEqual(images.count, 145)
        XCTAssertEqual(Set(images.map(\.id)).count, 145)
        XCTAssertGreaterThan(batchCount, 1)
        XCTAssertEqual(Set(folders), Set([root, nested.deletingLastPathComponent(), nested]))
    }

    func test_scanEvents_preCanceledConsumerDoesNotTouchFileSystem() async throws {
        let source = ControlledFolderScanSourceForTraversal(entries: [])
        let service = DefaultFileSystemService(scanSource: source)
        let root = try XCTUnwrap(root)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            for try await _ in service.scanEvents(root, recursive: true) {}
        }

        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(source.validationCount, 0)
            XCTAssertEqual(source.cursorCount, 0)
        }
    }

    func test_scanEvents_cancelWaitsForWorkerExitAndStopsFurtherEntries() async throws {
        let image = root.appendingPathComponent("visible.jpg")
        try Data([0xFF, 0xD8]).write(to: image)
        let source = ControlledFolderScanSourceForTraversal(entries: [image, image], blocksFirstEntry: true)
        let service = DefaultFileSystemService(scanSource: source)
        let root = try XCTUnwrap(root)
        let consumerFinished = XCTestExpectation(description: "Canceled consumer waits for worker exit")
        let task = Task {
            defer { consumerFinished.fulfill() }
            for try await _ in service.scanEvents(root, recursive: true) {}
        }
        await fulfillment(of: [source.firstEntryStarted], timeout: 2)
        task.cancel()
        let completion = await XCTWaiter.fulfillment(of: [consumerFinished], timeout: 0.05)
        XCTAssertEqual(completion, .timedOut, "Cancellation must wait for the blocked worker to exit")
        source.releaseFirstEntry.signal()

        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(source.entryCount, 1)
            XCTAssertEqual(source.exitCount, 1, "Iteration must end only after the enumerator releases its resources")
        }
    }

    func test_scanEvents_subtreeFailureRemainsPartialAndOtherImagesSurvive() async throws {
        let image = root.appendingPathComponent("visible.jpg")
        try Data([0xFF, 0xD8]).write(to: image)
        let child = root.appendingPathComponent("restricted", isDirectory: true)
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        let source = ControlledFolderScanSourceForTraversal(entries: [image], issue: (child, error))
        let service = DefaultFileSystemService(scanSource: source)
        var images: [ImageFile] = []
        var issues: [FolderScanIssue] = []
        for try await event in service.scanEvents(root, recursive: true) {
            switch event {
            case .batch(let batch, _): images.append(contentsOf: batch)
            case .issue(let issue): issues.append(issue)
            }
        }

        XCTAssertEqual(images.map(\.url), [image])
        XCTAssertEqual(issues, [FolderScanIssue(folderURL: child, message: error.localizedDescription)])
    }

    func test_scanEvents_rootFailureIsFatalAndDoesNotCreateCursor() async throws {
        let source = ControlledFolderScanSourceForTraversal(entries: [], rootError: FileSystemError.folderAccessDenied)
        let service = DefaultFileSystemService(scanSource: source)
        do {
            for try await _ in service.scanEvents(root, recursive: true) {}
            XCTFail("Expected inaccessible root to fail")
        } catch FileSystemError.folderAccessDenied {
            XCTAssertEqual(source.cursorCount, 0)
        }
    }

    func test_scanEvents_rootEnumerationErrorIsFatalInsteadOfPartialSuccess() async throws {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        let source = ControlledFolderScanSourceForTraversal(entries: [], issue: (root, error))
        let service = DefaultFileSystemService(scanSource: source)
        do {
            for try await _ in service.scanEvents(root, recursive: true) {}
            XCTFail("Expected root enumeration error to fail")
        } catch FileSystemError.scanningFailed(let cause) {
            XCTAssertEqual((cause as NSError).code, error.code)
        }
    }

    func test_scanEvents_removedFileDoesNotHideSurvivingSibling() async throws {
        let removed = root.appendingPathComponent("removed.jpg")
        let image = root.appendingPathComponent("visible.jpg")
        try Data([0xFF, 0xD8]).write(to: image)
        let source = ControlledFolderScanSourceForTraversal(entries: [removed, image])
        let service = DefaultFileSystemService(scanSource: source)
        var images: [ImageFile] = []
        var issues: [FolderScanIssue] = []
        for try await event in service.scanEvents(root, recursive: true) {
            switch event {
            case .batch(let batch, _): images.append(contentsOf: batch)
            case .issue(let issue): issues.append(issue)
            }
        }

        XCTAssertEqual(images.map(\.url), [image])
        XCTAssertTrue(issues.isEmpty)
    }

    func test_scanEvents_aliasFilesAreExcludedEvenWithImageExtension() async throws {
        let image = root.appendingPathComponent("visible.jpg")
        try Data([0xFF, 0xD8]).write(to: image)
        let alias = root.appendingPathComponent("alias.jpg")
        let bookmark = try image.bookmarkData(options: .suitableForBookmarkFile,
                                              includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(bookmark, to: alias)
        XCTAssertTrue(try alias.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true)

        let images = try await DefaultFileSystemService().scanFolder(root, recursive: true)

        XCTAssertEqual(images.map(\.url), [image])
    }

    func test_scanEvents_nonregularFilesAndExternalLinksAreExcluded() async throws {
        let image = root.appendingPathComponent("visible.jpg")
        try Data([0xFF, 0xD8]).write(to: image)
        let external = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,
                                                                                     isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: external) }
        let externalImage = external.appendingPathComponent("outside.jpg")
        try Data([0xFF, 0xD8]).write(to: externalImage)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked.jpg"),
                                                   withDestinationURL: externalImage)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked-folder"),
                                                   withDestinationURL: external)
        let pipe = root.appendingPathComponent("pipe.jpg")
        XCTAssertEqual(mkfifo(pipe.path, 0o600), 0)

        let images = try await DefaultFileSystemService().scanFolder(root, recursive: true)

        XCTAssertEqual(images.map(\.url), [image])
    }
}

private final class ControlledFolderScanSourceForTraversal: FolderScanSource, @unchecked Sendable {
    let firstEntryStarted = XCTestExpectation(description: "Enumerator entered first entry")
    let releaseFirstEntry = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private let entries: [URL]
    private let blocksFirstEntry: Bool
    private let issue: (URL, Error)?
    private let rootError: Error?
    private var validations = 0
    private var cursors = 0
    private var entriesRequested = 0
    private var exits = 0

    init(entries: [URL], blocksFirstEntry: Bool = false, issue: (URL, Error)? = nil, rootError: Error? = nil) {
        self.entries = entries
        self.blocksFirstEntry = blocksFirstEntry
        self.issue = issue
        self.rootError = rootError
    }

    var validationCount: Int { lock.withLock { validations } }
    var cursorCount: Int { lock.withLock { cursors } }
    var entryCount: Int { lock.withLock { entriesRequested } }
    var exitCount: Int { lock.withLock { exits } }

    func validateRoot(_ url: URL) throws {
        lock.withLock { validations += 1 }
        if let rootError { throw rootError }
    }

    func makeCursor(at url: URL, recursive: Bool,
                    errorHandler: @escaping (URL, Error) -> Bool) throws -> any FolderScanCursor {
        lock.withLock { cursors += 1 }
        if let (url, error) = issue { _ = errorHandler(url, error) }
        return ControlledFolderScanCursorForTraversal(source: self)
    }

    func resourceValues(at url: URL) throws -> URLResourceValues {
        try DefaultFolderScanSource().resourceValues(at: url)
    }

    func nextURL() -> URL? {
        let index = lock.withLock {
            let index = entriesRequested
            entriesRequested += 1
            return index
        }
        if index == 0, blocksFirstEntry {
            firstEntryStarted.fulfill()
            releaseFirstEntry.wait()
        }
        return index < entries.count ? entries[index] : nil
    }

    func exited() { lock.withLock { exits += 1 } }
}

private final class ControlledFolderScanCursorForTraversal: FolderScanCursor {
    private let source: ControlledFolderScanSourceForTraversal
    init(source: ControlledFolderScanSourceForTraversal) { self.source = source }
    deinit { source.exited() }
    func nextURL() -> URL? { source.nextURL() }
    func skipDescendants() {}
}

@MainActor
final class RecursiveFolderSessionRegressionTests: XCTestCase {
    func test_restoreRecursiveScope_requestsDescendantsAndPublishesCombinedCollection() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let child = fixture.root.appendingPathComponent("child", isDirectory: true)
        let nested = makeImage(in: child, name: "nested.jpg")
        let direct = makeImage(in: fixture.root, name: "direct.jpg")
        fixture.model.restoreLastFolder(fixture.root, includeSubfolders: true)
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)
        let finished = expectation(description: "Recursive session finishes")
        let subscription = fixture.model.$isScanning.dropFirst().filter { !$0 }.prefix(1)
            .sink { _ in finished.fulfill() }
        defer { subscription.cancel() }
        fixture.service.emit(.batch(images: [direct, nested], folders: [fixture.root, child]))
        fixture.service.finish()
        await fulfillment(of: [finished], timeout: 2)

        XCTAssertEqual(fixture.service.requestedScopes, [true])
        XCTAssertTrue(fixture.model.includeSubfolders)
        XCTAssertTrue(fixture.model.selectedFolderContent?.includeSubfolders == true)
        XCTAssertTrue(fixture.model.selectedFolderContent?.isComplete == true)
        XCTAssertEqual(Set(fixture.model.selectedFolderContent?.imageFiles ?? []), Set([direct, nested]))
        XCTAssertEqual(Set(fixture.model.selectedFolderContent?.discoveredFolders ?? []), Set([fixture.root, child]))
    }

    func test_emptyRecursiveTree_completesAsBrowsableEmptyState() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let child = fixture.root.appendingPathComponent("empty-child", isDirectory: true)
        fixture.model.restoreLastFolder(fixture.root, includeSubfolders: true)
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)
        let finished = expectation(description: "Empty recursive session finishes")
        let subscription = fixture.model.$isScanning.dropFirst().filter { !$0 }.prefix(1)
            .sink { _ in finished.fulfill() }
        defer { subscription.cancel() }
        fixture.service.emit(.batch(images: [], folders: [fixture.root, child]))
        fixture.service.finish()
        await fulfillment(of: [finished], timeout: 2)

        XCTAssertNil(fixture.model.currentError)
        XCTAssertEqual(fixture.model.selectedFolderURL, fixture.root)
        XCTAssertEqual(fixture.model.selectedFolderContent?.imageFiles.count, 0)
        XCTAssertTrue(fixture.model.selectedFolderContent?.isComplete == true)
        XCTAssertEqual(Set(fixture.model.selectedFolderContent?.discoveredFolders ?? []), Set([fixture.root, child]))
    }

    func test_cancelAfterBatch_retainsIncompleteImagesAndRejectsLateEvents() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let discovered = makeImage(in: fixture.root, name: "first.jpg")
        let late = makeImage(in: fixture.root, name: "late.jpg")
        fixture.model.restoreLastFolder(fixture.root, includeSubfolders: true)
        await fulfillment(of: [fixture.service.scanStarted], timeout: 2)
        let firstPublished = expectation(description: "First batch is usable before completion")
        let firstSubscription = fixture.model.$selectedFolderContent.compactMap { $0 }
            .filter { !$0.isComplete && $0.imageFiles.contains(discovered) }.prefix(1)
            .sink { _ in firstPublished.fulfill() }
        fixture.service.emit(.batch(images: [discovered], folders: [fixture.root]))
        await fulfillment(of: [firstPublished], timeout: 2)
        firstSubscription.cancel()
        fixture.model.cancelScanning()
        let latePublished = expectation(description: "Late canceled events must not publish")
        latePublished.isInverted = true
        let lateSubscription = fixture.model.$selectedFolderContent.dropFirst()
            .sink { _ in latePublished.fulfill() }
        fixture.service.emit(.batch(images: [late], folders: []))
        fixture.service.emit(.issue(FolderScanIssue(folderURL: fixture.root, message: "Late failure")))
        fixture.service.finish()
        await fulfillment(of: [latePublished], timeout: 0.1)
        lateSubscription.cancel()

        XCTAssertFalse(fixture.model.isScanning)
        XCTAssertNil(fixture.model.currentError)
        XCTAssertEqual(fixture.model.selectedFolderContent?.imageFiles, [discovered])
        XCTAssertFalse(fixture.model.selectedFolderContent?.isComplete ?? true)
        XCTAssertEqual(fixture.manager.currentURL, fixture.root)
    }

    private func makeImage(in folder: URL, name: String) -> ImageFile {
        ImageFile(url: folder.appendingPathComponent(name), name: name, type: .jpeg,
                  size: 1, creationDate: .distantPast, modificationDate: .distantPast)
    }

    private func makeFixture() throws -> RecursiveFolderSessionFixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,
                                                                                 isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "RecursiveFolderSessionRegressionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let service = ControlledFolderEventService()
        let manager = SecurityScopedAccessManager()
        let model = FolderSelectionViewModel(fileSystemService: service,
                                             preferencesService: DefaultPreferencesService(userDefaults: defaults),
                                             accessManager: manager)
        return RecursiveFolderSessionFixture(model: model, service: service, manager: manager,
                                             root: root, defaults: defaults, suite: suite)
    }
}

@MainActor
private struct RecursiveFolderSessionFixture {
    let model: FolderSelectionViewModel
    let service: ControlledFolderEventService
    let manager: SecurityScopedAccessManager
    let root: URL
    let defaults: UserDefaults
    let suite: String

    func cleanup() {
        model.cancelScanning()
        manager.stopCurrentAccess()
        service.finish()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}

private final class ControlledFolderEventService: FileSystemService, @unchecked Sendable {
    let scanStarted = XCTestExpectation(description: "Incremental scan starts")
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<FolderScanEvent, Error>.Continuation?
    private var scopes: [Bool] = []

    var requestedScopes: [Bool] { lock.withLock { scopes } }

    func scanEvents(_ url: URL, recursive: Bool) -> AsyncThrowingStream<FolderScanEvent, Error> {
        AsyncThrowingStream { continuation in
            lock.withLock {
                self.continuation = continuation
                scopes.append(recursive)
            }
            scanStarted.fulfill()
        }
    }

    func emit(_ event: FolderScanEvent) { _ = lock.withLock { continuation?.yield(event) } }
    func finish() {
        let active = lock.withLock {
            let active = continuation
            continuation = nil
            return active
        }
        active?.finish()
    }
    func scanFolder(_ url: URL, recursive: Bool) async throws -> [ImageFile] {
        XCTFail("Incremental sessions must use the event API")
        return []
    }
    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never> { Empty().eraseToAnyPublisher() }
    func createSecurityScopedBookmark(for url: URL) -> Data? { nil }
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL? { nil }
    func isSupportedImageFile(_ url: URL) -> Bool { true }
    func getFileType(for url: URL) -> UTType? { .jpeg }
}

import XCTest
import Combine
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

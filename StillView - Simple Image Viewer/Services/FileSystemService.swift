import Foundation
import Combine
import UniformTypeIdentifiers

/// Protocol defining file system operations for StillView - Simple Image Viewer
protocol FileSystemService {
    /// Scan a folder for supported image files
    /// - Parameters:
    ///   - url: The folder URL to scan
    ///   - recursive: Whether to scan subfolders recursively
    /// - Returns: Array of ImageFile objects found in the folder
    func scanFolder(_ url: URL, recursive: Bool) async throws -> [ImageFile]
    
    /// Monitor a folder for changes and emit updates
    /// - Parameter url: The folder URL to monitor
    /// - Returns: A publisher that emits updated file lists when changes occur
    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never>
    
    /// Create a security-scoped bookmark for sandboxed access
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data that can be stored and used later
    func createSecurityScopedBookmark(for url: URL) -> Data?
    
    /// Resolve a security-scoped bookmark to access a previously selected folder
    /// - Parameter bookmarkData: The bookmark data to resolve
    /// - Returns: The resolved URL if successful
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL?
    
    /// Check if a file URL represents a supported image format
    /// - Parameter url: The file URL to check
    /// - Returns: True if the file is a supported image format
    func isSupportedImageFile(_ url: URL) -> Bool
    
    /// Get the UTType for a file URL
    /// - Parameter url: The file URL to analyze
    /// - Returns: The UTType of the file, or nil if it cannot be determined
    func getFileType(for url: URL) -> UTType?
}

/// Default implementation of FileSystemService
class DefaultFileSystemService: FileSystemService, @unchecked Sendable {
    private let fileManager = FileManager.default
    private var folderMonitors: [URL: DispatchSourceFileSystemObject] = [:]
    private var monitorSubjects: [URL: PassthroughSubject<[ImageFile], Never>] = [:]
    
    deinit {
        // Clean up any active monitors
        folderMonitors.values.forEach { $0.cancel() }
    }
    
    func scanFolder(_ url: URL, recursive: Bool = false) async throws -> [ImageFile] {
        guard url.hasDirectoryPath else {
            throw FileSystemError.folderNotFound
        }
        
        // Check if we can access the folder
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.folderNotFound
        }
        
        // Ensure we have security-scoped access to the folder during scanning
        // Note: The caller should have already started accessing the security-scoped resource
        // We just need to verify we can access the folder
        var imageFiles: [ImageFile] = []
        
        do {
            if recursive {
                imageFiles = try await scanFolderRecursively(url)
            } else {
                imageFiles = try await scanFolderShallow(url)
            }
        } catch {
            throw FileSystemError.scanningFailed(error)
        }
        
        if imageFiles.isEmpty {
            throw FileSystemError.noImagesFound
        }
        
        // Sort files by name for consistent ordering
        return imageFiles.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    private func scanFolderShallow(_ url: URL) async throws -> [ImageFile] {
        let contents = try fileManager.contentsOfDirectory(at: url, 
                                                          includingPropertiesForKeys: [.contentTypeKey, .isDirectoryKey], 
                                                          options: [.skipsHiddenFiles])
        
        var imageFiles: [ImageFile] = []
        
        for fileURL in contents {
            // Skip directories in shallow scan
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                continue
            }
            
            // Try to create ImageFile, skip if not supported
            do {
                let imageFile = try ImageFile(url: fileURL)
                imageFiles.append(imageFile)
            } catch {
                // Skip unsupported files silently
                continue
            }
        }
        
        return imageFiles
    }
    
    private func scanFolderRecursively(_ url: URL) async throws -> [ImageFile] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.scanningFailed(NSError(domain: "FileSystemService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                    return
                }
                
                do {
                    var imageFiles: [ImageFile] = []
                    
                    if let enumerator = self.fileManager.enumerator(at: url, 
                                                                   includingPropertiesForKeys: [.contentTypeKey, .isDirectoryKey], 
                                                                   options: [.skipsHiddenFiles]) {
                        
                        for case let fileURL as URL in enumerator {
                            // Skip directories
                            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                            if resourceValues.isDirectory == true {
                                continue
                            }
                            
                            // Try to create ImageFile, skip if not supported
                            do {
                                let imageFile = try ImageFile(url: fileURL)
                                imageFiles.append(imageFile)
                            } catch {
                                // Skip unsupported files silently
                                continue
                            }
                        }
                    }
                    
                    continuation.resume(returning: imageFiles)
                } catch {
                    continuation.resume(throwing: FileSystemError.scanningFailed(error))
                }
            }
        }
    }
    
    func monitorFolder(_ url: URL) -> AnyPublisher<[ImageFile], Never> {
        // Clean up existing monitor for this URL if it exists
        if let existingMonitor = folderMonitors[url] {
            existingMonitor.cancel()
            folderMonitors.removeValue(forKey: url)
            monitorSubjects.removeValue(forKey: url)
        }
        
        let subject = PassthroughSubject<[ImageFile], Never>()
        monitorSubjects[url] = subject
        
        // Create file descriptor for monitoring
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            // If we can't monitor, return a publisher that never emits
            return Empty<[ImageFile], Never>().eraseToAnyPublisher()
        }
        
        // Create dispatch source for file system events
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )
        
        source.setEventHandler { [weak self] in
            self?.handleFolderChange(url: url, subject: subject)
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        folderMonitors[url] = source
        source.resume()
        
        return subject.eraseToAnyPublisher()
    }
    
    private func handleFolderChange(url: URL, subject: PassthroughSubject<[ImageFile], Never>) {
        Task {
            do {
                let updatedFiles = try await scanFolder(url, recursive: false)
                await MainActor.run {
                    subject.send(updatedFiles)
                }
            } catch {
                // On error, send empty array
                await MainActor.run {
                    subject.send([])
                }
            }
        }
    }
    
    func createSecurityScopedBookmark(for url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            return nil
        }
    }
    
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) -> URL? {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                return nil
            }
            
            // Note: The caller is responsible for calling stopAccessingSecurityScopedResource()
            // when done with the URL
            return url
        } catch {
            return nil
        }
    }
    
    func isSupportedImageFile(_ url: URL) -> Bool {
        guard let fileType = getFileType(for: url) else {
            return false
        }
        return fileType.isSupportedImageType
    }
    
    func getFileType(for url: URL) -> UTType? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
            return resourceValues.contentType
        } catch {
            // Fallback to extension-based detection
            return UTType.fromFileExtension(url.pathExtension)
        }
    }
}

/// Errors that can occur during file system operations
enum FileSystemError: LocalizedError {
    case folderAccessDenied
    case folderNotFound
    case noImagesFound
    case scanningFailed(Error)
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .folderAccessDenied:
            return "Unable to access the selected folder. Please check permissions."
        case .folderNotFound:
            return "The selected folder could not be found."
        case .noImagesFound:
            return "No supported images found in the selected folder."
        case .scanningFailed(let error):
            return "Failed to scan folder: \(error.localizedDescription)"
        case .bookmarkCreationFailed:
            return "Failed to create security bookmark for folder access."
        case .bookmarkResolutionFailed:
            return "Failed to resolve security bookmark. Please reselect the folder."
        }
    }
}
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

    /// Discover bounded batches. Normal termination means discovery completed successfully.
    func scanEvents(_ url: URL, recursive: Bool) -> AsyncThrowingStream<FolderScanEvent, Error>
    
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

/// A recoverable failure reading a descendant folder. Other branches remain usable.
struct FolderScanIssue: Equatable, Sendable {
    let folderURL: URL
    let message: String
}

enum FolderScanEvent: Sendable {
    case batch(images: [ImageFile], folders: [URL])
    case issue(FolderScanIssue)
}

extension FileSystemService {
    /// Keeps existing test doubles and services compatible with incremental discovery.
    func scanEvents(_ url: URL, recursive: Bool) -> AsyncThrowingStream<FolderScanEvent, Error> {
        guard !Task.isCancelled else {
            return AsyncThrowingStream { $0.finish(throwing: CancellationError()) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try Task.checkCancellation()
                    let images = try await scanFolder(url, recursive: recursive)
                    try Task.checkCancellation()
                    let folders = Set(images.map { $0.url.deletingLastPathComponent() }).union([url])
                    continuation.yield(.batch(images: images, folders: folders.sorted { $0.path < $1.path }))
                    continuation.finish()
                } catch FileSystemError.noImagesFound {
                    continuation.yield(.batch(images: [], folders: [url]))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Injected traversal operations make cancellation and partial errors deterministic in tests.
protocol FolderScanSource: Sendable {
    func validateRoot(_ url: URL) throws
    func makeCursor(at url: URL, recursive: Bool,
                    errorHandler: @escaping (URL, Error) -> Bool) throws -> any FolderScanCursor
    func resourceValues(at url: URL) throws -> URLResourceValues
}

protocol FolderScanCursor: AnyObject {
    func nextURL() -> URL?
    func skipDescendants()
}

struct DefaultFolderScanSource: FolderScanSource {
    static let resourceKeys: Set<URLResourceKey> = [
        .contentTypeKey, .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
        .isAliasFileKey, .isPackageKey, .isHiddenKey, .fileSizeKey,
        .creationDateKey, .contentModificationDateKey
    ]

    func validateRoot(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { throw FileSystemError.folderNotFound }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FileSystemError.folderAccessDenied
        }
    }

    func makeCursor(at url: URL, recursive: Bool,
                    errorHandler: @escaping (URL, Error) -> Bool) throws -> any FolderScanCursor {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        if !recursive { options.insert(.skipsSubdirectoryDescendants) }
        let canonicalRoot = try url.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath ?? url.path
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(Self.resourceKeys),
            options: options, errorHandler: { failedURL, error in
                errorHandler(DefaultFolderScanCursor.scopedURL(failedURL, root: url,
                                                               canonicalRoot: canonicalRoot), error)
            }
        ) else { throw FileSystemError.folderAccessDenied }
        return DefaultFolderScanCursor(enumerator: enumerator, root: url, canonicalRoot: canonicalRoot)
    }

    func resourceValues(at url: URL) throws -> URLResourceValues {
        try url.resourceValues(forKeys: Self.resourceKeys)
    }
}

private final class DefaultFolderScanCursor: FolderScanCursor {
    private let enumerator: FileManager.DirectoryEnumerator
    private let root: URL
    private let canonicalRoot: String

    init(enumerator: FileManager.DirectoryEnumerator, root: URL, canonicalRoot: String) {
        self.enumerator = enumerator
        self.root = root
        self.canonicalRoot = canonicalRoot
    }

    func nextURL() -> URL? {
        guard let url = enumerator.nextObject() as? URL else { return nil }
        var scoped = Self.scopedURL(url, root: root, canonicalRoot: canonicalRoot)
        if scoped != url, let values = try? url.resourceValues(forKeys: DefaultFolderScanSource.resourceKeys) {
            // Keep enumeration's prefetched metadata after rebasing a system path alias such as /var.
            for (key, value) in values.allValues { scoped.setTemporaryResourceValue(value, forKey: key) }
        }
        return scoped
    }

    func skipDescendants() { enumerator.skipDescendants() }

    static func scopedURL(_ url: URL, root: URL, canonicalRoot: String) -> URL {
        let prefix = canonicalRoot.hasSuffix("/") ? canonicalRoot : canonicalRoot + "/"
        if url.path == canonicalRoot { return root }
        guard url.path.hasPrefix(prefix) else { return url }
        let relativePath = String(url.path.dropFirst(prefix.count))
        return root.appendingPathComponent(relativePath, isDirectory: url.hasDirectoryPath)
    }
}

/// A bounded channel that waits for worker exit when cancellation interrupts a pending next().
/// Swift may short-circuit a pre-canceled next(), so the worker also owns a balanced root grant.
private final class FolderScanChannel: @unchecked Sendable {
    private let condition = NSCondition()
    private var events: [FolderScanEvent] = []
    private var pendingNext: CheckedContinuation<FolderScanEvent?, Error>?
    private var isFinished = false
    private var failure: Error?
    private var cancellationRequested = false

    var isCancelled: Bool { condition.withLock { cancellationRequested } }

    func cancel() {
        condition.lock()
        cancellationRequested = true
        events.removeAll()
        condition.broadcast()
        condition.unlock()
    }

    func send(_ event: FolderScanEvent) -> Bool {
        condition.lock()
        while events.count >= 2 && !cancellationRequested && !isFinished { condition.wait() }
        guard !cancellationRequested && !isFinished else {
            condition.unlock()
            return false
        }
        let waiting = pendingNext
        pendingNext = nil
        if waiting == nil { events.append(event) }
        condition.unlock()
        waiting?.resume(returning: event)
        return true
    }

    func finish(throwing error: Error? = nil) {
        condition.lock()
        isFinished = true
        failure = cancellationRequested ? CancellationError() : error
        let waiting = pendingNext
        pendingNext = nil
        let result = failure
        condition.broadcast()
        condition.unlock()
        if let result { waiting?.resume(throwing: result) } else { waiting?.resume(returning: nil) }
    }

    func next() async throws -> FolderScanEvent? {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                receive(continuation)
            }
        } onCancel: {
            self.cancel()
        }
    }

    private func receive(_ continuation: CheckedContinuation<FolderScanEvent?, Error>) {
        condition.lock()
        if !cancellationRequested, !events.isEmpty {
            let event = events.removeFirst()
            condition.signal()
            condition.unlock()
            continuation.resume(returning: event)
        } else if isFinished {
            let error = cancellationRequested ? CancellationError() : failure
            condition.unlock()
            if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: nil) }
        } else {
            pendingNext = continuation
            condition.unlock()
        }
    }
}

/// The stream owns this lifetime; the worker owns only the channel. Dropping an unused/abandoned
/// stream cancels the worker even when bounded backpressure is waiting for the consumer.
private final class FolderScanOperation: @unchecked Sendable {
    private let root: URL
    private let recursive: Bool
    private let source: any FolderScanSource
    private let batchSize: Int
    private let channel = FolderScanChannel()
    private let startLock = NSLock()
    private var hasStarted = false

    init(root: URL, recursive: Bool, source: any FolderScanSource, batchSize: Int) {
        self.root = root
        self.recursive = recursive
        self.source = source
        self.batchSize = batchSize
    }

    deinit { channel.cancel() }

    func next() async throws -> FolderScanEvent? {
        let shouldStart = startLock.withLock {
            if hasStarted { return false }
            hasStarted = true
            return true
        }
        if shouldStart {
            if Task.isCancelled {
                channel.cancel()
                channel.finish()
            } else {
                let root = root
                let recursive = recursive
                let source = source
                let batchSize = batchSize
                let channel = channel
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try Self.discover(root: root, recursive: recursive, source: source,
                                          batchSize: batchSize, channel: channel)
                        channel.finish()
                    } catch {
                        channel.finish(throwing: error)
                    }
                }
            }
        }
        return try await channel.next()
    }

    private static func discover(root: URL, recursive: Bool, source: any FolderScanSource,
                                 batchSize: Int, channel: FolderScanChannel) throws {
        guard !channel.isCancelled else { throw CancellationError() }
        let ownsScopedAccess = root.startAccessingSecurityScopedResource()
        defer { if ownsScopedAccess { root.stopAccessingSecurityScopedResource() } }
        try source.validateRoot(root)
        guard !channel.isCancelled else { throw CancellationError() }
        var rootFailure: Error?
        let cursor = try source.makeCursor(at: root, recursive: recursive) { url, error in
            guard !channel.isCancelled else { return false }
            if url.standardizedFileURL == root.standardizedFileURL {
                rootFailure = error
                return false
            }
            return channel.send(.issue(FolderScanIssue(folderURL: url, message: error.localizedDescription)))
        }
        var images: [ImageFile] = []
        var folders = [root]
        var lastPublication = Date()
        while !channel.isCancelled, let url = cursor.nextURL() {
            guard !channel.isCancelled else { throw CancellationError() }
            do {
                let values = try source.resourceValues(at: url)
                try appendEntry(url: url, values: values, recursive: recursive, cursor: cursor,
                                images: &images, folders: &folders)
            } catch {
                // A file removed between enumeration and metadata lookup is not a subtree failure.
                if !isMissingFile(error) {
                    let folder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
                    guard channel.send(.issue(FolderScanIssue(folderURL: folder,
                                                              message: error.localizedDescription))) else {
                        throw CancellationError()
                    }
                }
            }
            if images.count + folders.count >= batchSize || Date().timeIntervalSince(lastPublication) >= 0.1 {
                try publish(images: &images, folders: &folders, channel: channel)
                lastPublication = Date()
            }
        }
        guard !channel.isCancelled else { throw CancellationError() }
        if let rootFailure { throw FileSystemError.scanningFailed(rootFailure) }
        try publish(images: &images, folders: &folders, channel: channel)
    }

    private static func appendEntry(url: URL, values: URLResourceValues, recursive: Bool,
                                    cursor: any FolderScanCursor, images: inout [ImageFile],
                                    folders: inout [URL]) throws {
        if values.isSymbolicLink == true || values.isAliasFile == true || values.isHidden == true {
            if values.isDirectory == true { cursor.skipDescendants() }
            return
        }
        if values.isDirectory == true {
            if values.isPackage == true {
                cursor.skipDescendants()
                return
            }
            if recursive { folders.append(url) }
        } else if values.isRegularFile == true,
                  let type = values.contentType, type.isSupportedImageType {
            images.append(try ImageFile(url: url, resourceValues: values))
        }
    }

    private static func publish(images: inout [ImageFile], folders: inout [URL],
                                channel: FolderScanChannel) throws {
        guard !images.isEmpty || !folders.isEmpty else { return }
        guard channel.send(.batch(images: images, folders: folders)) else { throw CancellationError() }
        images.removeAll(keepingCapacity: true)
        folders.removeAll(keepingCapacity: true)
    }

    private static func isMissingFile(_ error: Error) -> Bool {
        let error = error as NSError
        return (error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError)
            || (error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT))
    }
}

/// Default implementation of FileSystemService
class DefaultFileSystemService: FileSystemService, @unchecked Sendable {
    private var folderMonitors: [URL: DispatchSourceFileSystemObject] = [:]
    private var monitorSubjects: [URL: PassthroughSubject<[ImageFile], Never>] = [:]
    
    deinit {
        // Clean up any active monitors
        folderMonitors.values.forEach { $0.cancel() }
    }
    
    private let scanSource: any FolderScanSource
    private let scanBatchSize: Int

    init(scanSource: any FolderScanSource = DefaultFolderScanSource(), scanBatchSize: Int = 64) {
        self.scanSource = scanSource
        self.scanBatchSize = max(1, scanBatchSize)
    }

    func scanFolder(_ url: URL, recursive: Bool = false) async throws -> [ImageFile] {
        var images: [ImageFile] = []
        for try await event in scanEvents(url, recursive: recursive) {
            if case .batch(let batch, _) = event {
                images.append(contentsOf: batch)
            }
        }
        try Task.checkCancellation()
        guard !images.isEmpty else { throw FileSystemError.noImagesFound }
        return images.sorted { lhs, rhs in
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.id.path < rhs.id.path
        }
    }

    func scanEvents(_ url: URL, recursive: Bool) -> AsyncThrowingStream<FolderScanEvent, Error> {
        guard !Task.isCancelled else {
            return AsyncThrowingStream { $0.finish(throwing: CancellationError()) }
        }
        let operation = FolderScanOperation(root: url, recursive: recursive, source: scanSource,
                                            batchSize: scanBatchSize)
        return AsyncThrowingStream(unfolding: { try await operation.next() })
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
                options: [.withSecurityScope],
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

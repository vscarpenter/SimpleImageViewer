import SwiftUI
import ImageIO

/// Docked bottom filmstrip (Studio redesign). Selection is shown by an accent
/// ring only — no index badges (finding V5).
struct FilmstripView: View {
    @ObservedObject var viewModel: ImageViewerViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    fileprivate static let barHeight: CGFloat = 78
    fileprivate static let thumbSize = CGSize(width: 84, height: 56)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(viewModel.allImageFiles.enumerated()), id: \.element.id) { index, imageFile in
                        FilmstripThumbnail(
                            imageFile: imageFile,
                            folderPath: viewModel.includeSubfolders ? viewModel.relativeFolderPath(for: imageFile) : nil,
                            isSelected: index == viewModel.currentIndex,
                            onTap: { viewModel.jumpToImage(at: index) }
                        )
                        .thumbnailContextMenu(for: imageFile, at: index, viewModel: viewModel)
                        .id(imageFile.url)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: Self.barHeight)
            }
            .frame(height: Self.barHeight)
            .background(Color.appChrome)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.appHairline)
                    .frame(height: 1)
            }
            .onChange(of: StudioSelectionPosition(url: viewModel.currentImageFile?.url, index: viewModel.currentIndex)) { _, selection in
                guard let selectedURL = selection.url else { return }
                if reduceMotion {
                    proxy.scrollTo(selectedURL, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(selectedURL, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let selectedURL = viewModel.currentImageFile?.url {
                    proxy.scrollTo(selectedURL, anchor: .center)
                }
            }
        }
        .id(viewModel.currentFolderURL)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filmstrip")
    }
}

/// URL owns identity; position changes still scroll the same selected image after sorting.
struct StudioSelectionPosition: Equatable {
    let url: URL?
    let index: Int
}

/// One 84×56 fill-cropped thumbnail in the filmstrip.
private struct FilmstripThumbnail: View {
    let imageFile: ImageFile
    let folderPath: String?
    let isSelected: Bool
    let onTap: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    private var imageLabel: String {
        guard let folderPath else { return imageFile.name }
        return "\(imageFile.name), \(folderPath.isEmpty ? "This folder" : folderPath)"
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.appTileFill)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundColor(.appSecondaryText)
                        }
                }
            }
            .frame(width: FilmstripView.thumbSize.width, height: FilmstripView.thumbSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(isSelected || isHovered ? 1.0 : 0.65)
            .overlay {
                if isSelected {
                    // 2 pt accent ring with a 2 pt offset outside the thumb
                    RoundedRectangle(cornerRadius: 7)
                        .inset(by: -3)
                        .stroke(Color.systemAccent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .focusedValue(\.viewerKeyboardFocus, .control)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(imageLabel)
        .accessibilityLabel(imageLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task(id: StudioThumbnailRequest(imageFile: imageFile, maxPixelSize: 168)) {
            thumbnail = nil
            let loadedThumbnail = await StudioThumbnailLoader.load(
                from: imageFile.url,
                maxPixelSize: Int(FilmstripView.thumbSize.width * 2)
            )
            guard !Task.isCancelled else { return }
            thumbnail = loadedThumbnail
        }
    }
}

/// Request identity includes the discovered file revision so a refresh restarts visible tile tasks.
struct StudioThumbnailRequest: Hashable {
    let url: URL
    let byteCount: Int64
    let modificationDate: Date
    let maxPixelSize: Int

    init(imageFile: ImageFile, maxPixelSize: Int) {
        url = imageFile.url.standardizedFileURL
        byteCount = imageFile.size
        modificationDate = imageFile.modificationDate
        self.maxPixelSize = maxPixelSize
    }
}

/// One bounded cache and decode scheduler shared by every grid and filmstrip window.
enum StudioThumbnailLoader {
    static let shared = StudioThumbnailPipeline()

    private static let pressureSource: DispatchSourceMemoryPressure = {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical], queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { Task { await shared.removeAllCachedImages() } }
        source.resume()
        return source
    }()

    static func load(from url: URL, maxPixelSize: Int) async -> NSImage? {
        _ = pressureSource
        let workerLease = SecurityScopedAccessManager.shared.acquireWorkerAccess(for: url)
        defer { withExtendedLifetime(workerLease) {} }
        while !Task.isCancelled {
            switch await shared.loadOutcome(from: url, maxPixelSize: maxPixelSize, workerLease: workerLease) {
            case .image(let image):
                return Task.isCancelled ? nil : image
            case .busy:
                // The visible tile owns this wait. Scrolling it away cancels the retry without
                // retaining another internal job, while very large windows eventually fill in.
                do { try await Task.sleep(nanoseconds: 80_000_000) } catch { return nil }
            }
        }
        return nil
    }
}

/// ImageIO decoding itself is synchronous. Cancellation removes queued work immediately and
/// cancels active workers; an active ImageIO call keeps its slot until it returns, preventing
/// rapid scrolling from starting more decodes than the configured worker limit.
actor StudioThumbnailPipeline {
    typealias Decoder = @Sendable (URL, Int) async -> NSImage?

    enum LoadOutcome {
        case image(NSImage?)
        case busy
    }

    private struct Key: Hashable {
        let url: URL
        let byteCount: Int
        let modificationDate: Date
        let maxPixelSize: Int

        static func read(from url: URL, maxPixelSize: Int) -> Key? {
            let freshURL = URL(fileURLWithPath: url.path).standardizedFileURL
            guard let values = try? freshURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let byteCount = values.fileSize, let modificationDate = values.contentModificationDate else {
                return nil
            }
            return Key(
                url: freshURL, byteCount: byteCount, modificationDate: modificationDate,
                maxPixelSize: min(2048, max(1, maxPixelSize))
            )
        }
    }

    private struct Entry {
        let image: NSImage
        let cost: Int
        var lastAccess: UInt64
    }

    private struct Job {
        let identifier = UUID()
        let workerLease: SecurityScopedResourceLease?
        var waiters: [UUID: CheckedContinuation<NSImage?, Never>] = [:]
    }

    struct Statistics {
        let cachedCount: Int
        let cachedBytes: Int
        let activeWorkers: Int
        let queuedJobs: Int
        let waitingRequests: Int
        let peakWorkers: Int
        let completedDecodes: Int
        let cacheHits: Int
    }

    private let maxCachedCount: Int
    private let maxCachedBytes: Int
    private let maxWorkers: Int
    private let maxQueuedJobs: Int
    private let maxWaitingRequests: Int
    private let decoder: Decoder
    private var cache: [Key: Entry] = [:]
    private var cachedBytes = 0
    private var accessSequence: UInt64 = 0
    private var jobs: [Key: Job] = [:]
    private var queuedKeys: [Key] = []
    private var requestKeys: [UUID: Key] = [:]
    private var workers: [UUID: Task<Void, Never>] = [:]
    private var peakWorkers = 0
    private var completedDecodes = 0
    private var cacheHits = 0

    init(
        maxCachedCount: Int = 256,
        maxCachedBytes: Int = 64 * 1024 * 1024,
        maxWorkers: Int = 2,
        maxQueuedJobs: Int = 128,
        maxWaitingRequests: Int = 256,
        decoder: @escaping Decoder = { url, pixels in
            await StudioThumbnailPipeline.decode(from: url, maxPixelSize: pixels)
        }
    ) {
        self.maxCachedCount = max(1, maxCachedCount)
        self.maxCachedBytes = max(0, maxCachedBytes)
        self.maxWorkers = max(1, maxWorkers)
        self.maxQueuedJobs = max(1, maxQueuedJobs)
        self.maxWaitingRequests = max(1, maxWaitingRequests)
        self.decoder = decoder
    }

    func load(
        from url: URL, maxPixelSize: Int, workerLease: SecurityScopedResourceLease? = nil
    ) async -> NSImage? {
        switch await loadOutcome(from: url, maxPixelSize: maxPixelSize, workerLease: workerLease) {
        case .image(let image): return image
        case .busy: return nil
        }
    }

    func loadOutcome(
        from url: URL, maxPixelSize: Int, workerLease: SecurityScopedResourceLease? = nil
    ) async -> LoadOutcome {
        let retainedLease = workerLease ?? SecurityScopedAccessManager.shared.acquireWorkerAccess(for: url)
        defer { withExtendedLifetime(retainedLease) {} }
        guard !Task.isCancelled, let key = Key.read(from: url, maxPixelSize: maxPixelSize) else { return .image(nil) }
        discardObsoleteRevisions(for: key)
        if var entry = cache[key] {
            accessSequence &+= 1
            entry.lastAccess = accessSequence
            cache[key] = entry
            cacheHits += 1
            return .image(entry.image)
        }
        guard requestKeys.count < maxWaitingRequests,
              jobs[key] != nil || queuedKeys.count < maxQueuedJobs else { return .busy }
        let requestID = UUID()
        let image = await withTaskCancellationHandler {
            guard !Task.isCancelled else { return nil as NSImage? }
            return await withCheckedContinuation { continuation in
                enqueue(key: key, requestID: requestID, workerLease: retainedLease, continuation: continuation)
            }
        } onCancel: {
            Task { await self.cancel(requestID: requestID) }
        }
        return .image(Task.isCancelled ? nil : image)
    }

    func removeAllCachedImages() {
        cache.removeAll()
        cachedBytes = 0
    }

    var statistics: Statistics {
        Statistics(
            cachedCount: cache.count, cachedBytes: cachedBytes,
            activeWorkers: workers.count, queuedJobs: queuedKeys.count,
            waitingRequests: requestKeys.count, peakWorkers: peakWorkers,
            completedDecodes: completedDecodes, cacheHits: cacheHits
        )
    }

    private func enqueue(
        key: Key, requestID: UUID, workerLease: SecurityScopedResourceLease?,
        continuation: CheckedContinuation<NSImage?, Never>
    ) {
        guard requestKeys.count < maxWaitingRequests else {
            continuation.resume(returning: nil)
            return
        }
        if var job = jobs[key] {
            job.waiters[requestID] = continuation
            jobs[key] = job
        } else {
            guard queuedKeys.count < maxQueuedJobs else {
                continuation.resume(returning: nil)
                return
            }
            var job = Job(workerLease: workerLease)
            job.waiters[requestID] = continuation
            jobs[key] = job
            queuedKeys.append(key)
        }
        requestKeys[requestID] = key
        startAvailableWorkers()
    }

    private func cancel(requestID: UUID) {
        guard let key = requestKeys.removeValue(forKey: requestID), var job = jobs[key],
              let continuation = job.waiters.removeValue(forKey: requestID) else { return }
        continuation.resume(returning: nil)
        if job.waiters.isEmpty {
            jobs.removeValue(forKey: key)
            queuedKeys.removeAll { $0 == key }
            workers[job.identifier]?.cancel()
        } else {
            jobs[key] = job
        }
    }

    private func startAvailableWorkers() {
        while workers.count < maxWorkers, !queuedKeys.isEmpty {
            let key = queuedKeys.removeFirst()
            guard let job = jobs[key], !job.waiters.isEmpty else { continue }
            let identifier = job.identifier
            let decoder = self.decoder
            let workerLease = job.workerLease
            workers[identifier] = Task.detached(priority: .userInitiated) { [weak self] in
                // Caller cancellation can resume its waiter before ImageIO returns. The immutable
                // root lease belongs to this worker until decode and revision validation finish.
                defer { withExtendedLifetime(workerLease) {} }
                let image = Task.isCancelled ? nil : await decoder(key.url, key.maxPixelSize)
                let acceptedImage = Task.isCancelled ? nil : image
                await self?.complete(key: key, identifier: identifier, image: acceptedImage)
            }
            peakWorkers = max(peakWorkers, workers.count)
        }
    }

    private func complete(key: Key, identifier: UUID, image: NSImage?) {
        workers.removeValue(forKey: identifier)
        completedDecodes += 1
        if let job = jobs[key], job.identifier == identifier {
            jobs.removeValue(forKey: key)
            let acceptedImage = Key.read(from: key.url, maxPixelSize: key.maxPixelSize) == key ? image : nil
            if let acceptedImage { store(acceptedImage, for: key) }
            for (requestID, continuation) in job.waiters {
                requestKeys.removeValue(forKey: requestID)
                continuation.resume(returning: acceptedImage)
            }
        }
        startAvailableWorkers()
    }

    private func discardObsoleteRevisions(for key: Key) {
        let obsoleteKeys = cache.keys.filter {
            $0.url == key.url && ($0.byteCount != key.byteCount || $0.modificationDate != key.modificationDate)
        }
        for oldKey in obsoleteKeys { removeCachedImage(for: oldKey) }
    }

    private func store(_ image: NSImage, for key: Key) {
        let cost = ImageCache.decodedMemoryCost(of: image)
        guard cost > 0, cost <= maxCachedBytes else { return }
        while cache.count >= maxCachedCount || cachedBytes > maxCachedBytes - cost {
            guard let oldest = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else { break }
            removeCachedImage(for: oldest)
        }
        accessSequence &+= 1
        cache[key] = Entry(image: image, cost: cost, lastAccess: accessSequence)
        cachedBytes += cost
    }

    private func removeCachedImage(for key: Key) {
        if let entry = cache.removeValue(forKey: key) { cachedBytes -= entry.cost }
    }

    nonisolated static func decode(from url: URL, maxPixelSize: Int) async -> NSImage? {
        guard !Task.isCancelled,
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              !Task.isCancelled else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(2048, max(1, maxPixelSize))
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              !Task.isCancelled else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}

// MARK: - Preview
#Preview {
    FilmstripView(viewModel: ImageViewerViewModel())
        .frame(width: 900)
}

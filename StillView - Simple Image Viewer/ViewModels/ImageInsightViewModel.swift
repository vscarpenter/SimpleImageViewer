import Combine
import Foundation

@MainActor
final class ImageInsightViewModel: ObservableObject {
    @Published private(set) var state: ImageInsightState = .idle
    @Published private(set) var result: ImageInsightResult?
    @Published private(set) var generationError: String?
    @Published private(set) var textState: ImageTextExtractionState = .idle
    @Published private(set) var textResult: ImagePerceptionResult?
    @Published private(set) var textExtractionError: String?

    private let service: any ImageInsightGenerating
    private let resultCacheLimit: Int
    private var currentInput: ImageInsightInput?
    private var currentAvailability: ImageInsightAvailability = .unavailable(.unknown)
    private var generationTask: Task<Void, Never>?
    private var activeGenerationID: UUID?
    private var textExtractionTask: Task<Void, Never>?
    private var activeTextExtractionID: UUID?
    private var cachedText: [ImageInsightInput: ImagePerceptionResult] = [:]
    private var cachedResults: [ImageInsightInput: ImageInsightResult] = [:]
    private var cacheOrder: [ImageInsightInput] = []

    init(service: any ImageInsightGenerating, resultCacheLimit: Int = 20) {
        self.service = service
        self.resultCacheLimit = max(1, resultCacheLimit)
    }

    deinit {
        generationTask?.cancel()
        textExtractionTask?.cancel()
    }

    var canExtractText: Bool {
        currentInput != nil && activeGenerationID == nil && activeTextExtractionID == nil
    }

    func prepareForImage(_ input: ImageInsightInput?, availability: ImageInsightAvailability) {
        let imageChanged = currentInput != input
        guard input == nil || imageChanged || currentAvailability != availability else { return }

        if imageChanged {
            cancelGeneration(resetToIdle: false)
            cancelTextExtraction()
            currentInput = input
            generationError = nil
            textExtractionError = nil
            if let input {
                discardOlderVersions(of: input)
                result = cachedResults[input]
                textResult = cachedText[input]
                if result != nil || textResult != nil { touchCacheEntry(input) }
            } else {
                result = nil
                textResult = nil
            }
            restoreTextState()
        }
        currentAvailability = availability
        guard availability.isAvailable else {
            cancelGeneration(resetToIdle: false)
            state = .unavailable(availability.message)
            return
        }
        guard input != nil else {
            state = .unavailable(ImageInsightAvailability.unavailable(.imageUnavailable).message)
            return
        }
        if case .generating = state, !imageChanged { return }
        restoreResultOrIdle()
    }

    func updateAvailability(_ availability: ImageInsightAvailability) {
        prepareForImage(currentInput, availability: availability)
    }

    func generate() {
        guard currentAvailability.isAvailable else {
            state = .unavailable(currentAvailability.message)
            return
        }
        guard let input = currentInput else {
            state = .unavailable(ImageInsightAvailability.unavailable(.imageUnavailable).message)
            return
        }

        cancelGeneration(resetToIdle: false)
        cancelTextExtraction()
        let generationID = UUID()
        activeGenerationID = generationID
        generationError = nil
        textExtractionError = nil
        textState = .extracting
        state = .generating
        generationTask = Task { [weak self, service, input] in
            do {
                let result = try await service.generateInsight(for: input) { [weak self] perception in
                    await self?.acceptText(perception, generationID: generationID, input: input)
                }
                try Task.checkCancellation()
                guard let self, self.isCurrentGeneration(generationID, input: input) else { return }
                self.finishGeneration()
                self.cache(result, for: input)
                self.result = result
                self.state = .result(result)
            } catch is CancellationError {
                guard let self, self.isCurrentGeneration(generationID, input: input) else { return }
                self.finishGeneration()
                self.restoreResultOrIdle()
            } catch {
                guard let self, self.isCurrentGeneration(generationID, input: input) else { return }
                self.finishGeneration()
                if error as? ImageInsightError == .inputChanged {
                    self.invalidateCurrentResults(for: input)
                }
                self.generationError = error.localizedDescription
                if let result = self.result {
                    self.state = .result(result)
                } else {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    func cancelGeneration(resetToIdle: Bool = true) {
        // Invalidate before canceling: a service may finish or throw after cancellation.
        activeGenerationID = nil
        generationTask?.cancel()
        generationTask = nil
        if activeTextExtractionID == nil { restoreTextState() }
        if resetToIdle, case .generating = state {
            restoreResultOrIdle()
        }
    }

    func extractText() {
        guard canExtractText, let input = currentInput else { return }
        cancelTextExtraction()
        let extractionID = UUID()
        activeTextExtractionID = extractionID
        textExtractionError = nil
        textState = .extracting
        textExtractionTask = Task { [weak self, service, input] in
            do {
                let perception = try await service.extractText(for: input)
                try Task.checkCancellation()
                guard let self, self.isCurrentExtraction(extractionID, input: input) else { return }
                self.finishTextExtraction()
                self.acceptText(perception, for: input)
            } catch is CancellationError {
                guard let self, self.isCurrentExtraction(extractionID, input: input) else { return }
                self.finishTextExtraction()
                self.restoreTextState()
            } catch {
                guard let self, self.isCurrentExtraction(extractionID, input: input) else { return }
                self.finishTextExtraction()
                if error as? ImageInsightError == .inputChanged {
                    self.invalidateCurrentResults(for: input)
                    self.restoreResultOrIdle()
                }
                self.textExtractionError = error.localizedDescription
                if let textResult = self.textResult {
                    self.textState = .result(textResult)
                } else {
                    self.textState = .failed(error.localizedDescription)
                }
            }
        }
    }

    func cancelTextExtraction() {
        activeTextExtractionID = nil
        textExtractionTask?.cancel()
        textExtractionTask = nil
        restoreTextState()
    }

    /// A known external edit invalidates stored evidence before replacement metadata or pixels can finish.
    func invalidateCurrentImage() {
        cancelGeneration(resetToIdle: false)
        cancelTextExtraction()
        if let input = currentInput { invalidateCurrentResults(for: input) }
        currentInput = nil
        generationError = nil
        textExtractionError = nil
        restoreResultOrIdle()
    }

    private func isCurrentExtraction(_ extractionID: UUID, input: ImageInsightInput) -> Bool {
        activeTextExtractionID == extractionID && currentInput == input
    }

    private func finishTextExtraction() {
        activeTextExtractionID = nil
        textExtractionTask = nil
    }

    private func acceptText(_ perception: ImagePerceptionResult, generationID: UUID, input: ImageInsightInput) {
        guard isCurrentGeneration(generationID, input: input) else { return }
        acceptText(perception, for: input)
    }

    private func acceptText(_ perception: ImagePerceptionResult, for input: ImageInsightInput) {
        cachedText[input] = perception
        touchCacheEntry(input)
        trimCache()
        textResult = perception
        textExtractionError = nil
        textState = .result(perception)
    }

    private func restoreTextState() {
        textState = textResult.map(ImageTextExtractionState.result) ?? .idle
    }

    private func invalidateCurrentResults(for input: ImageInsightInput) {
        result = nil
        textResult = nil
        cachedResults.removeValue(forKey: input)
        cachedText.removeValue(forKey: input)
        cacheOrder.removeAll { $0 == input }
        restoreTextState()
    }

    private func isCurrentGeneration(_ generationID: UUID, input: ImageInsightInput) -> Bool {
        activeGenerationID == generationID && currentInput == input && currentAvailability.isAvailable
    }

    private func finishGeneration() {
        activeGenerationID = nil
        generationTask = nil
        restoreTextState()
    }

    private func restoreResultOrIdle() {
        if !currentAvailability.isAvailable {
            state = .unavailable(currentAvailability.message)
        } else if currentInput == nil {
            state = .unavailable(ImageInsightAvailability.unavailable(.imageUnavailable).message)
        } else if let result {
            state = .result(result)
        } else {
            state = .idle
        }
    }

    private func discardOlderVersions(of input: ImageInsightInput) {
        guard let url = input.imageURL else { return }
        let obsoleteInputs = cacheOrder.filter { $0.imageURL == url && $0 != input }
        for obsoleteInput in obsoleteInputs {
            cachedResults.removeValue(forKey: obsoleteInput)
            cachedText.removeValue(forKey: obsoleteInput)
        }
        cacheOrder.removeAll { obsoleteInputs.contains($0) }
    }

    private func cache(_ result: ImageInsightResult, for input: ImageInsightInput) {
        cachedResults[input] = result
        touchCacheEntry(input)
        trimCache()
    }

    private func trimCache() {
        while cacheOrder.count > resultCacheLimit {
            let oldest = cacheOrder.removeFirst()
            cachedResults.removeValue(forKey: oldest)
            cachedText.removeValue(forKey: oldest)
        }
    }

    private func touchCacheEntry(_ input: ImageInsightInput) {
        cacheOrder.removeAll { $0 == input }
        cacheOrder.append(input)
    }
}

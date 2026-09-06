import Combine
import Foundation

@MainActor
final class ImageInsightViewModel: ObservableObject {
    @Published private(set) var state: ImageInsightState = .idle
    @Published private(set) var result: ImageInsightResult?
    @Published private(set) var generationError: String?

    private let service: any ImageInsightGenerating
    private let resultCacheLimit: Int
    private var currentInput: ImageInsightInput?
    private var currentAvailability: ImageInsightAvailability = .unavailable(.unknown)
    private var generationTask: Task<Void, Never>?
    private var activeGenerationID: UUID?
    private var cachedResults: [ImageInsightInput: ImageInsightResult] = [:]
    private var cacheOrder: [ImageInsightInput] = []

    init(service: any ImageInsightGenerating, resultCacheLimit: Int = 20) {
        self.service = service
        self.resultCacheLimit = max(1, resultCacheLimit)
    }

    deinit {
        generationTask?.cancel()
    }

    func prepareForImage(_ input: ImageInsightInput?, availability: ImageInsightAvailability) {
        let imageChanged = currentInput != input
        guard input == nil || imageChanged || currentAvailability != availability else { return }

        if imageChanged {
            cancelGeneration(resetToIdle: false)
            currentInput = input
            generationError = nil
            if let input {
                discardOlderVersions(of: input)
                result = cachedResults[input]
                if result != nil { touchCacheEntry(input) }
            } else {
                result = nil
            }
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
        let generationID = UUID()
        activeGenerationID = generationID
        generationError = nil
        state = .generating
        generationTask = Task { [weak self, service, input] in
            do {
                let result = try await service.generateInsight(for: input)
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
        if resetToIdle, case .generating = state {
            restoreResultOrIdle()
        }
    }

    private func isCurrentGeneration(_ generationID: UUID, input: ImageInsightInput) -> Bool {
        activeGenerationID == generationID && currentInput == input && currentAvailability.isAvailable
    }

    private func finishGeneration() {
        activeGenerationID = nil
        generationTask = nil
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
        }
        cacheOrder.removeAll { obsoleteInputs.contains($0) }
    }

    private func cache(_ result: ImageInsightResult, for input: ImageInsightInput) {
        cachedResults[input] = result
        touchCacheEntry(input)
        while cacheOrder.count > resultCacheLimit {
            cachedResults.removeValue(forKey: cacheOrder.removeFirst())
        }
    }

    private func touchCacheEntry(_ input: ImageInsightInput) {
        cacheOrder.removeAll { $0 == input }
        cacheOrder.append(input)
    }
}

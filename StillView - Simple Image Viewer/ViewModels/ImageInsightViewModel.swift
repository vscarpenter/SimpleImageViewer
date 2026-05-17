import Combine
import Foundation

@MainActor
final class ImageInsightViewModel: ObservableObject {
    @Published private(set) var state: ImageInsightState = .idle

    private let service: any ImageInsightGenerating
    private var currentInput: ImageInsightInput?
    private var generationTask: Task<Void, Never>?

    init(service: any ImageInsightGenerating) {
        self.service = service
    }

    deinit {
        generationTask?.cancel()
    }

    func prepareForImage(_ input: ImageInsightInput?, availability: ImageInsightAvailability) {
        generationTask?.cancel()
        generationTask = nil
        currentInput = input

        guard availability.isAvailable else {
            state = .unavailable(availability.message)
            return
        }

        guard input != nil else {
            state = .unavailable(ImageInsightAvailability.unavailable(.imageUnavailable).message)
            return
        }

        state = .idle
    }

    func updateAvailability(_ availability: ImageInsightAvailability) {
        guard !availability.isAvailable else {
            if case .unavailable = state, currentInput != nil {
                state = .idle
            }
            return
        }

        cancelGeneration(resetToIdle: false)
        state = .unavailable(availability.message)
    }

    func generate() {
        guard let input = currentInput else {
            state = .unavailable(ImageInsightAvailability.unavailable(.imageUnavailable).message)
            return
        }

        generationTask?.cancel()
        state = .generating

        generationTask = Task { [service, input] in
            do {
                let result = try await service.generateInsight(for: input)
                try Task.checkCancellation()
                await MainActor.run {
                    self.state = .result(result)
                    self.generationTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    if case .generating = self.state {
                        self.state = .idle
                    }
                    self.generationTask = nil
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(error.localizedDescription)
                    self.generationTask = nil
                }
            }
        }
    }

    func cancelGeneration(resetToIdle: Bool = true) {
        generationTask?.cancel()
        generationTask = nil

        if resetToIdle, case .generating = state {
            state = currentInput == nil ? .unavailable(ImageInsightAvailability.unavailable(.imageUnavailable).message) : .idle
        }
    }
}

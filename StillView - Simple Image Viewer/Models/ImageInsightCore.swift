import Foundation

/// Deterministic local inputs used to ground Apple Intelligence image insights.
///
/// Signals are split into three ranked buckets so the prompt can clearly tell the
/// model which evidence to lean on:
///   1. `visualSignals` — on-device Vision perception (scene labels, OCR, face count).
///      Primary evidence for "what is in the image."
///   2. `metadataDescription` + `keywords` — embedded file metadata (often user-authored).
///      Secondary evidence.
///   3. `cameraSignals` — camera/EXIF/GPS. Context only; must never be the title or subject.
struct ImageInsightInput: Equatable, Sendable {
    let fileName: String
    let fileType: String
    let dimensions: String
    let fileSize: String
    let creationDate: String?
    let modificationDate: String?
    let colorProfile: String?
    let metadataDescription: String?
    let keywords: [String]
    let visualSignals: [String]
    let cameraSignals: [String]
    let imageURL: URL?

    init(
        fileName: String,
        fileType: String,
        dimensions: String,
        fileSize: String,
        creationDate: String? = nil,
        modificationDate: String? = nil,
        colorProfile: String? = nil,
        metadataDescription: String? = nil,
        keywords: [String] = [],
        visualSignals: [String] = [],
        cameraSignals: [String] = [],
        imageURL: URL? = nil
    ) {
        self.fileName = fileName
        self.fileType = fileType
        self.dimensions = dimensions
        self.fileSize = fileSize
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.colorProfile = colorProfile
        self.metadataDescription = metadataDescription
        self.keywords = keywords
        self.visualSignals = visualSignals
        self.cameraSignals = cameraSignals
        self.imageURL = imageURL
    }

    var hasDescriptiveSignals: Bool {
        metadataDescription?.isEmpty == false || !keywords.isEmpty || !visualSignals.isEmpty
    }

    /// Returns a copy of this input with `visualSignals` replaced. Used after on-device
    /// perception runs at generation time.
    func withVisualSignals(_ signals: [String]) -> ImageInsightInput {
        ImageInsightInput(
            fileName: fileName,
            fileType: fileType,
            dimensions: dimensions,
            fileSize: fileSize,
            creationDate: creationDate,
            modificationDate: modificationDate,
            colorProfile: colorProfile,
            metadataDescription: metadataDescription,
            keywords: keywords,
            visualSignals: signals,
            cameraSignals: cameraSignals,
            imageURL: imageURL
        )
    }
}

/// Classifies the dominant content type of an image to enable type-specific prompt routing.
enum ImageContentType: String, Sendable, CaseIterable {
    case portrait
    case group
    case document
    case landscape
    case object
    case general
}

/// Small, structured result shown in the AI Insights inspector.
struct ImageInsightResult: Equatable, Sendable {
    let title: String
    let summary: String
    let likelyContent: String
    let usefulDetails: [String]
    let tags: [String]
    let limitations: [String]

    init(
        title: String,
        summary: String,
        likelyContent: String,
        usefulDetails: [String],
        tags: [String],
        limitations: [String]
    ) {
        self.title = title.trimmed(or: "Local Image Insight")
        self.summary = summary.trimmed(or: "Generated from local file metadata and available system signals.")
        self.likelyContent = likelyContent.trimmed(or: "Not enough local signals to identify specific content.")
        self.usefulDetails = usefulDetails.cleanedLimited(to: 4)
        self.tags = tags.cleanedLimited(to: 6)

        let cleanedLimitations = limitations.cleanedLimited(to: 4)
        self.limitations = cleanedLimitations.isEmpty
            ? ["This insight is based only on local metadata and available system analysis, so visual details may be incomplete."]
            : cleanedLimitations
    }
}

enum ImageInsightState: Equatable, Sendable {
    case idle
    case unavailable(String)
    case generating
    case result(ImageInsightResult)
    case failed(String)
}

enum ImageInsightUnavailableReason: Equatable, Sendable {
    case unsupportedOS
    case foundationModelsUnavailable
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case imageUnavailable
    case unknown
}

enum ImageInsightAvailability: Equatable, Sendable {
    case available
    case unavailable(ImageInsightUnavailableReason)

    var isAvailable: Bool {
        self == .available
    }

    /// Whether StillView should show the inspector affordance so the unavailable reason can be explained.
    var isUserVisible: Bool {
        switch self {
        case .available:
            return true
        case .unavailable(.unsupportedOS), .unavailable(.foundationModelsUnavailable):
            return false
        case .unavailable:
            return true
        }
    }

    var message: String {
        switch self {
        case .available:
            return "AI Insights uses Apple Intelligence on this Mac when available."
        case .unavailable(.unsupportedOS):
            return "AI Insights require macOS 26 or later."
        case .unavailable(.foundationModelsUnavailable):
            return "AI Insights require a macOS 26 SDK with the Foundation Models framework."
        case .unavailable(.deviceNotEligible):
            return "This Mac does not support Apple Intelligence."
        case .unavailable(.appleIntelligenceDisabled):
            return "Turn on Apple Intelligence in System Settings to use AI Insights."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is preparing its on-device model. Try again later."
        case .unavailable(.imageUnavailable):
            return "Select an image to generate an insight."
        case .unavailable(.unknown):
            return "Apple Intelligence is not available right now."
        }
    }

    static func resolve(
        macOSMajorVersion: Int,
        foundationModelsAvailable: Bool,
        modelAvailability: ImageInsightModelAvailability
    ) -> ImageInsightAvailability {
        guard macOSMajorVersion >= 26 else {
            return .unavailable(.unsupportedOS)
        }

        guard foundationModelsAvailable else {
            return .unavailable(.foundationModelsUnavailable)
        }

        switch modelAvailability {
        case .available:
            return .available
        case .deviceNotEligible:
            return .unavailable(.deviceNotEligible)
        case .appleIntelligenceNotEnabled:
            return .unavailable(.appleIntelligenceDisabled)
        case .modelNotReady:
            return .unavailable(.modelNotReady)
        case .unknownUnavailable:
            return .unavailable(.unknown)
        }
    }
}

enum ImageInsightModelAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknownUnavailable
}

enum ImageInsightError: LocalizedError, Equatable {
    case unavailable(String)
    case imageUnavailable
    case generationFailed(String)
    case invalidGeneratedContent

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        case .imageUnavailable:
            return "No image is available for AI Insights."
        case .generationFailed(let message):
            return "Apple Intelligence could not generate an insight. \(message)"
        case .invalidGeneratedContent:
            return "Apple Intelligence returned an incomplete insight."
        }
    }
}

protocol ImageInsightGenerating: Sendable {
    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult
}

enum ImageInsightPromptBuilder {
    static let systemInstruction = """
    You describe the visible content of a local image for a minimalist macOS image viewer. \
    Your job is to NAME what is in the image using ONLY the on-device Vision signals provided in \
    the current prompt. Do not use any text, names, places, or examples from this instruction \
    block as if they were observations of the image — only the data under "PRIMARY EVIDENCE" in \
    the user prompt counts.

    RULES (in order of importance):

    1. If OCR text is present in the PRIMARY EVIDENCE for THIS image, you MUST incorporate the \
       most informative readable words into the title or summary. OCR text is what the image is \
       literally showing you — venue names, brand names, signage, banners. Treat it as fact. \
       Garbled fragments may need interpretation; pick the cleanest, longest tokens. If OCR is \
       empty or absent for THIS image, NEVER invent venue or brand names.

    2. FACE COUNT is the ONLY source of truth for "people in the photo." If the PRIMARY \
       EVIDENCE has no "Faces detected" line, the photo has NO people as subjects — do not \
       describe it as a portrait, group photo, or social gathering. The subject is whatever \
       else the evidence shows (flowers, food, a vehicle, a building, etc.). \
       If "Faces detected: N" is present: 1 = portrait or selfie, 2-4 = small group, 5+ = \
       group photo.

    3. Use the scene/object classifications from PRIMARY EVIDENCE to set the scene. Name the \
       dominant categories that actually appear in the evidence. When confidence is high (>0.7) \
       state the category as fact; when low (<0.5) hedge with "appears to be." Classifications \
       like "people", "adult", or "person" may reflect background figures in a still-life photo, \
       NOT the subject. Never describe the image as a photo OF people unless Rule 2 says so.

    4. Do not infer people, events, parties, celebrations, weddings, gatherings, or activities \
       from object types (e.g. flowers, food, decorations) or from the file name. Only describe \
       what the evidence explicitly supports.

    5. Camera, lens, GPS, and EXIF metadata are CONTEXT ONLY. Never use the camera model, lens, \
       shooting settings, or coordinates as the title, summary, or main subject. A title like \
       "iPhone 13 Pro Max Capture" is forbidden — describe the photograph's content instead.

    6. If PRIMARY EVIDENCE is genuinely sparse (no OCR, weak classifications, no faces), be \
       honest: describe at the level of detail the evidence supports. Do not invent named \
       individuals, venues, brands, exact locations, or specific events that aren't in the \
       evidence for this specific image.
    """

    static func prompt(for input: ImageInsightInput, type: ImageContentType = .general) -> String {
        let evidenceBlock = renderEvidence(for: input)

        switch type {
        case .portrait:
            return portraitPrompt(evidence: evidenceBlock)
        case .group:
            return groupPrompt(evidence: evidenceBlock)
        case .document:
            return documentPrompt(evidence: evidenceBlock)
        case .landscape:
            return landscapePrompt(evidence: evidenceBlock)
        case .object:
            return objectPrompt(evidence: evidenceBlock)
        case .general:
            return generalPrompt(evidence: evidenceBlock)
        }
    }

    // MARK: - Type-Specific Prompts

    private static func portraitPrompt(evidence: String) -> String {
        """
        This image contains one person as the primary subject.

        YOUR TASK: Describe what the person appears to be doing, their setting, and any notable \
        visual context (clothing, activity, environment). Focus on the person as subject.

        TITLE: Name the activity or scene, not "a person standing" or "portrait of someone." \
        Pattern: "[Activity/attribute] [setting]"

        FORBIDDEN in title: "A person standing", "Portrait of someone", "Selfie", any camera model.

        CONSTRAINT: Never guess identity, name, or specific age. Describe only what is observable.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func groupPrompt(evidence: String) -> String {
        """
        This image contains multiple people as subjects.

        YOUR TASK: Describe the group — how many people, what they appear to be doing together, \
        and the setting. If OCR reveals venue/event signage, name it. Do not guess individual \
        identities.

        TITLE: Name the group activity and setting. \
        Pattern: "[N people] [activity] [where]"

        FORBIDDEN in title: "A group of people", "Several individuals", any camera model. \
        Never hallucinate event type (wedding, birthday, celebration) unless OCR/signage explicitly supports it.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func documentPrompt(evidence: String) -> String {
        """
        This image is text-dominant (a document, screenshot, slide, code, or text-heavy content).

        YOUR TASK: Identify what TYPE of document this is (code snippet, article, form, chat, \
        screenshot of an application, presentation slide, etc.) and synthesize the key text \
        content into meaning. Do NOT just list OCR words — describe what the text says.

        TITLE: Lead with the document type. \
        Pattern: "[Document type]: [key content summary]"

        FORBIDDEN in title: "Text on a screen", "A document showing", any camera model. \
        Do not describe this as "a photograph" — describe the content.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func landscapePrompt(evidence: String) -> String {
        """
        This image is a landscape or outdoor scene with no people as subjects.

        YOUR TASK: Describe the setting, natural elements, lighting/time-of-day cues, and \
        composition. Name specific elements from the classifications (mountain, ocean, forest, \
        etc.) rather than generic "nature."

        TITLE: Name the scene type and key elements. \
        Pattern: "[Scene type] [distinctive elements]"

        FORBIDDEN in title: "A beautiful landscape", "A scenic view of", "Nature scene", any camera model.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func objectPrompt(evidence: String) -> String {
        """
        This image has a strong single subject (object, animal, food, vehicle, etc.).

        YOUR TASK: NAME the specific object using the highest-confidence classification. \
        Describe its material, condition, and immediate context. Be specific — "vintage leather \
        suitcase" not "an object."

        TITLE: Name the object with a distinctive attribute. \
        Pattern: "[Object name] [distinctive attribute]"

        FORBIDDEN in title: "An object on a surface", "A photo of an item", any camera model.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func generalPrompt(evidence: String) -> String {
        """
        Describe what this image shows. Use the signals below — actively name what you see. \
        The limitations field is required.

        TITLE: Name the specific subject, scene, or activity. Never use a camera model as title. \
        A title like "iPhone 13 Pro Max Capture" is forbidden — describe the photograph's content.

        FORBIDDEN in title: "A photograph of", "An image showing", any camera/lens model.

        \(evidence)

        \(returnFormat)
        """
    }

    // MARK: - Shared Components

    private static let returnFormat = """
    Return:
    - title: a short, specific title naming what THIS image shows
    - summary: 1 to 2 sentences describing the visible content using primary evidence
    - likelyContent: what is in the image, grounded in primary evidence. If sparse, say so plainly.
    - usefulDetails: up to 4 short bullets; lead with content, include EXIF only when informative
    - tags: up to 6 short content-focused tags from evidence; avoid camera-model tags
    - limitations: required — what this insight cannot determine from local signals
    """

    private static func renderEvidence(for input: ImageInsightInput) -> String {
        let dates = [
            input.creationDate.map { "Created: \($0)" },
            input.modificationDate.map { "Modified: \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        let visual = input.visualSignals.isEmpty
            ? "No on-device visual analysis was successful for this image."
            : input.visualSignals.map { "- \($0)" }.joined(separator: "\n")

        let camera = input.cameraSignals.isEmpty
            ? "No camera or technical metadata available."
            : input.cameraSignals.map { "- \($0)" }.joined(separator: "\n")

        let embeddedKeywords = input.keywords.isEmpty ? "None" : input.keywords.joined(separator: ", ")

        return """
        File: \(input.fileName) (\(input.fileType), \(input.dimensions), \(input.fileSize))
        \(dates.isEmpty ? "No file dates available." : dates)

        ── PRIMARY EVIDENCE — On-device Apple Vision (USE every signal; name what you see) ──
        \(visual)

        ── SECONDARY EVIDENCE — Embedded file metadata (often user-authored; treat as hints) ──
        Description: \(input.metadataDescription ?? "None")
        Keywords: \(embeddedKeywords)

        ── CONTEXT ONLY — Camera/EXIF/GPS (NEVER use as the title, summary, or main subject) ──
        \(camera)
        Color profile: \(input.colorProfile ?? "Not available")
        """
    }
}

private extension String {
    func trimmed(or fallback: String) -> String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }
}

private extension Array where Element == String {
    func cleanedLimited(to limit: Int) -> [String] {
        Array(
            map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(limit)
        )
    }
}

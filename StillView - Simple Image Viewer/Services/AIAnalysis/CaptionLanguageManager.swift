import Foundation
import NaturalLanguage

/// Manages multi-language caption support using NaturalLanguage framework
/// Handles language detection, translation, and technical term preservation
final class CaptionLanguageManager {
    
    // MARK: - Supported Languages
    
    /// Languages supported for caption translation
    /// Starting with major languages, can be expanded based on user demand
    static let supportedLanguages: Set<String> = [
        "en", // English
        "es", // Spanish
        "fr", // French
        "de", // German
        "it", // Italian
        "pt", // Portuguese
        "ja", // Japanese
        "zh", // Chinese
        "ko", // Korean
        "ru", // Russian
        "ar", // Arabic
        "nl", // Dutch
        "sv", // Swedish
        "da", // Danish
        "no", // Norwegian
        "fi", // Finnish
        "pl", // Polish
        "tr", // Turkish
        "th", // Thai
        "vi"  // Vietnamese
    ]
    
    // MARK: - Technical Terms
    
    /// Technical photography terms that should be preserved during translation
    private static let technicalTerms: Set<String> = [
        "MP", "megapixel", "megapixels",
        "ISO", "aperture", "f-stop",
        "sharpness", "exposure", "resolution",
        "HDR", "RAW", "JPEG", "PNG", "HEIF",
        "RGB", "CMYK", "sRGB",
        "bokeh", "depth of field", "DOF",
        "rule of thirds", "golden hour",
        "histogram", "white balance",
        "focal length", "sensor", "lens"
    ]
    
    // MARK: - Singleton
    
    static let shared = CaptionLanguageManager()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Detect the system's preferred language
    func detectSystemLanguage() -> String {
        // Get the user's preferred language from system settings
        guard let preferredLanguage = Locale.preferredLanguages.first else {
            return "en" // Default to English
        }
        
        // Extract language code (e.g., "en-US" -> "en")
        let languageCode = String(preferredLanguage.prefix(2))
        
        // Return language code if supported, otherwise default to English
        return Self.supportedLanguages.contains(languageCode) ? languageCode : "en"
    }
    
    /// Check if a language is supported
    func isLanguageSupported(_ languageCode: String) -> Bool {
        return Self.supportedLanguages.contains(languageCode)
    }
    
    /// Translate caption to target language
    /// - Parameters:
    ///   - caption: The caption text to translate
    ///   - targetLanguage: The target language code (e.g., "es", "fr")
    /// - Returns: Translated caption, or original if translation fails
    func translateCaption(_ caption: String, to targetLanguage: String) -> String {
        // If target is English or not supported, return original
        guard targetLanguage != "en" else {
            return caption
        }
        
        guard isLanguageSupported(targetLanguage) else {
            return caption
        }
        
        // Preserve technical terms by replacing them with placeholders
        let (processedText, technicalTermMap) = preserveTechnicalTerms(in: caption)
        
        // Perform translation using NaturalLanguage framework
        let translatedText = performTranslation(processedText, to: targetLanguage)
        
        // Restore technical terms
        let finalText = restoreTechnicalTerms(in: translatedText, using: technicalTermMap)
        
        return finalText
    }
    
    /// Translate all caption fields in an ImageCaption
    /// - Parameters:
    ///   - caption: The ImageCaption to translate
    ///   - targetLanguage: The target language code
    /// - Returns: New ImageCaption with translated text
    func translateImageCaption(_ caption: ImageCaption, to targetLanguage: String) -> ImageCaption {
        // If already in target language or target is English, return original
        if caption.language == targetLanguage || targetLanguage == "en" {
            return caption
        }
        
        // If target language is not supported, return original with fallback note
        guard isLanguageSupported(targetLanguage) else {
            return caption // Fallback to original
        }
        
        // Translate each caption field
        let translatedShort = translateCaption(caption.shortCaption, to: targetLanguage)
        let translatedDetailed = translateCaption(caption.detailedCaption, to: targetLanguage)
        let translatedAccessibility = translateCaption(caption.accessibilityCaption, to: targetLanguage)
        let translatedTechnical = caption.technicalCaption.map { translateCaption($0, to: targetLanguage) }
        
        return ImageCaption(
            shortCaption: translatedShort,
            detailedCaption: translatedDetailed,
            accessibilityCaption: translatedAccessibility,
            technicalCaption: translatedTechnical,
            confidence: caption.confidence,
            language: targetLanguage
        )
    }
    
    // MARK: - Private Methods
    
    /// Preserve technical terms by replacing them with placeholders
    private func preserveTechnicalTerms(in text: String) -> (processedText: String, termMap: [String: String]) {
        var processedText = text
        var termMap: [String: String] = [:]
        var placeholderIndex = 0
        
        // Find and replace technical terms with placeholders
        for term in Self.technicalTerms {
            // Case-insensitive search
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let range = NSRange(processedText.startIndex..., in: processedText)
            let matches = regex.matches(in: processedText, range: range)
            
            // Replace matches in reverse order to maintain indices
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: processedText) else { continue }
                
                let matchedTerm = String(processedText[matchRange])
                let placeholder = "[[TECH_\(placeholderIndex)]]"
                termMap[placeholder] = matchedTerm
                
                processedText.replaceSubrange(matchRange, with: placeholder)
                placeholderIndex += 1
            }
        }
        
        return (processedText, termMap)
    }
    
    /// Restore technical terms from placeholders
    private func restoreTechnicalTerms(in text: String, using termMap: [String: String]) -> String {
        var restoredText = text
        
        // Replace placeholders with original technical terms
        for (placeholder, originalTerm) in termMap {
            restoredText = restoredText.replacingOccurrences(of: placeholder, with: originalTerm)
        }
        
        return restoredText
    }
    
    /// Perform translation using NaturalLanguage framework
    /// Note: This is a simplified implementation. For production, consider using
    /// Apple's Translation framework (iOS 15+/macOS 12+) or a cloud translation service
    private func performTranslation(_ text: String, to targetLanguage: String) -> String {
        // NaturalLanguage framework doesn't provide direct translation
        // This is a placeholder for the translation logic
        // In a real implementation, you would:
        // 1. Use Apple's Translation framework (if available)
        // 2. Use a cloud translation API (Google Translate, DeepL, etc.)
        // 3. Use a local ML translation model
        
        // For now, we'll use a simple dictionary-based approach for common phrases
        // and return the original text if no translation is available
        
        let translations = getCommonPhraseTranslations(for: targetLanguage)
        
        // Try to translate common phrases
        var translatedText = text
        for (english, translated) in translations {
            translatedText = translatedText.replacingOccurrences(
                of: english,
                with: translated,
                options: .caseInsensitive
            )
        }
        
        // If no translation occurred, return original
        // In production, this would call a real translation service
        return translatedText
    }
    
    /// Get common phrase translations for a target language
    /// This is a simplified approach - in production, use a proper translation service
    // swiftlint:disable:next function_body_length
    private func getCommonPhraseTranslations(for languageCode: String) -> [String: String] {
        switch languageCode {
        case "es": // Spanish
            return [
                "Image showing": "Imagen que muestra",
                "Portrait of": "Retrato de",
                "Landscape featuring": "Paisaje con",
                "indoors": "en interiores",
                "outdoors": "al aire libre",
                "with": "con",
                "containing": "que contiene",
                "depicts": "representa",
                "person": "persona",
                "people": "personas",
                "contains readable text": "contiene texto legible",
                "bright": "brillante",
                "dark": "oscuro",
                "vibrant": "vibrante",
                "monochromatic": "monocromático"
            ]
            
        case "fr": // French
            return [
                "Image showing": "Image montrant",
                "Portrait of": "Portrait de",
                "Landscape featuring": "Paysage avec",
                "indoors": "à l'intérieur",
                "outdoors": "à l'extérieur",
                "with": "avec",
                "containing": "contenant",
                "depicts": "représente",
                "person": "personne",
                "people": "personnes",
                "contains readable text": "contient du texte lisible",
                "bright": "lumineux",
                "dark": "sombre",
                "vibrant": "vibrant",
                "monochromatic": "monochrome"
            ]
            
        case "de": // German
            return [
                "Image showing": "Bild zeigt",
                "Portrait of": "Porträt von",
                "Landscape featuring": "Landschaft mit",
                "indoors": "drinnen",
                "outdoors": "draußen",
                "with": "mit",
                "containing": "enthaltend",
                "depicts": "zeigt",
                "person": "Person",
                "people": "Personen",
                "contains readable text": "enthält lesbaren Text",
                "bright": "hell",
                "dark": "dunkel",
                "vibrant": "lebhaft",
                "monochromatic": "monochrom"
            ]
            
        case "it": // Italian
            return [
                "Image showing": "Immagine che mostra",
                "Portrait of": "Ritratto di",
                "Landscape featuring": "Paesaggio con",
                "indoors": "al chiuso",
                "outdoors": "all'aperto",
                "with": "con",
                "containing": "contenente",
                "depicts": "raffigura",
                "person": "persona",
                "people": "persone",
                "contains readable text": "contiene testo leggibile",
                "bright": "luminoso",
                "dark": "scuro",
                "vibrant": "vibrante",
                "monochromatic": "monocromatico"
            ]
            
        case "pt": // Portuguese
            return [
                "Image showing": "Imagem mostrando",
                "Portrait of": "Retrato de",
                "Landscape featuring": "Paisagem com",
                "indoors": "dentro de casa",
                "outdoors": "ao ar livre",
                "with": "com",
                "containing": "contendo",
                "depicts": "retrata",
                "person": "pessoa",
                "people": "pessoas",
                "contains readable text": "contém texto legível",
                "bright": "brilhante",
                "dark": "escuro",
                "vibrant": "vibrante",
                "monochromatic": "monocromático"
            ]
            
        case "ja": // Japanese
            return [
                "Image showing": "画像：",
                "Portrait of": "肖像：",
                "Landscape featuring": "風景：",
                "indoors": "屋内",
                "outdoors": "屋外",
                "with": "と",
                "containing": "を含む",
                "depicts": "描写",
                "person": "人",
                "people": "人々",
                "contains readable text": "読み取り可能なテキストを含む",
                "bright": "明るい",
                "dark": "暗い",
                "vibrant": "鮮やか",
                "monochromatic": "モノクロ"
            ]
            
        case "zh": // Chinese (Simplified)
            return [
                "Image showing": "图像显示",
                "Portrait of": "肖像：",
                "Landscape featuring": "风景：",
                "indoors": "室内",
                "outdoors": "户外",
                "with": "与",
                "containing": "包含",
                "depicts": "描绘",
                "person": "人",
                "people": "人们",
                "contains readable text": "包含可读文本",
                "bright": "明亮",
                "dark": "黑暗",
                "vibrant": "鲜艳",
                "monochromatic": "单色"
            ]
            
        case "ko": // Korean
            return [
                "Image showing": "이미지:",
                "Portrait of": "초상화:",
                "Landscape featuring": "풍경:",
                "indoors": "실내",
                "outdoors": "야외",
                "with": "와",
                "containing": "포함",
                "depicts": "묘사",
                "person": "사람",
                "people": "사람들",
                "contains readable text": "읽을 수 있는 텍스트 포함",
                "bright": "밝은",
                "dark": "어두운",
                "vibrant": "생생한",
                "monochromatic": "단색"
            ]
            
        case "ru": // Russian
            return [
                "Image showing": "Изображение показывает",
                "Portrait of": "Портрет",
                "Landscape featuring": "Пейзаж с",
                "indoors": "в помещении",
                "outdoors": "на улице",
                "with": "с",
                "containing": "содержащий",
                "depicts": "изображает",
                "person": "человек",
                "people": "люди",
                "contains readable text": "содержит читаемый текст",
                "bright": "яркий",
                "dark": "темный",
                "vibrant": "яркий",
                "monochromatic": "монохромный"
            ]
            
        default:
            return [:] // No translations available, will return original text
        }
    }
    
    /// Get language name for display purposes
    func getLanguageName(for languageCode: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: languageCode)?.capitalized ?? languageCode.uppercased()
    }
}

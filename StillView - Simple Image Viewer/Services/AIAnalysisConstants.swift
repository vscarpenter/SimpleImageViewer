import Foundation

/// Centralized constants for AI image analysis
/// Keeps filtering logic and thresholds in one place for easy maintenance
enum AIAnalysisConstants {

    // MARK: - Classification Specificity Ranking

    /// Specificity levels for classifications (higher = more specific and useful)
    /// Level 5: Very specific objects (beer glass, wine glass, coffee cup, pizza, etc.)
    /// Level 4: Specific objects (furniture, electronics, food items, animals)
    /// Level 3: Moderate specificity (food, meal, vehicle, tableware)
    /// Level 2: Generic terms (person, people, object, document)
    /// Level 1: Very generic (thing, item)
    /// Level 0: Background/scene terms (sky, land, outdoor)
    static let specificityLevels: [String: Int] = [
        // Level 5: Very specific objects
        "beer glass": 5, "wine glass": 5, "champagne glass": 5, "cocktail glass": 5,
        "coffee cup": 5, "tea cup": 5, "mug": 5, "espresso": 5, "cappuccino": 5, "latte": 5,

        // Level 5: Specific foods
        "pizza": 5, "burger": 5, "hamburger": 5, "sandwich": 5, "salad": 5, "pasta": 5, "sushi": 5,
        "steak": 5, "chicken": 5, "lobster": 5, "shrimp": 5, "crab": 5,
        "taco": 5, "burrito": 5, "nachos": 5, "quesadilla": 5,
        "ramen": 5, "pho": 5, "noodles": 5, "rice": 5, "curry": 5,
        "cake": 5, "pie": 5, "cookie": 5, "ice cream": 5, "chocolate": 5, "donut": 5,
        "bread": 5, "bagel": 5, "croissant": 5, "baguette": 5, "pretzel": 5,
        "fruit": 4, "apple": 5, "banana": 5, "orange": 5, "strawberry": 5, "grape": 5,
        "vegetable": 4, "broccoli": 5, "carrot": 5, "tomato": 5, "potato": 5,
        "laptop": 5, "smartphone": 5, "tablet": 5, "camera": 5, "iphone": 5,
        "bicycle": 5, "motorcycle": 5, "sports car": 5, "sedan": 5, "suv": 5, "taxi": 5, "limousine": 5,
        "dog": 5, "cat": 5, "bird": 5, "horse": 5, "elephant": 5, "lion": 5, "tiger": 5,
        "guitar": 5, "piano": 5, "violin": 5, "drums": 5,
        "sofa": 5, "armchair": 5, "dining table": 5, "coffee table": 5, "desk": 5,
        
        // Level 5: Very specific vehicle brands and types
        "ferrari": 5, "porsche": 5, "lamborghini": 5, "maserati": 5, "aston martin": 5,
        "bmw": 5, "mercedes": 5, "audi": 5, "lexus": 5, "infiniti": 5,
        "convertible": 5, "roadster": 5, "coupe": 5, "sport car": 5, "supercar": 5,
        "pickup truck": 5, "semi truck": 5, "fire truck": 5, "ambulance": 5,

        // Level 4: Specific objects
        "furniture": 4, "chair": 4, "table": 4, "bed": 4, "shelf": 4,
        "electronics": 4, "computer": 4, "phone": 4, "television": 4, "monitor": 4,
        "dish": 4, "dessert": 4, "soup": 4, "breakfast": 4, "lunch": 4, "dinner": 4,
        "mammal": 4, "pet": 4, "wildlife": 4, "insect": 4, "reptile": 4,
        "instrument": 4, "musical": 4,
        "bottle": 4, "glass": 4, "cup": 4, "plate": 4, "bowl": 4, "fork": 4, "knife": 4, "spoon": 4,
        "automobile": 4, "car": 4, "truck": 4, "bus": 4,
        
        // Level 4: Specific vehicle types (removed duplicates: motorcycle and sports car already at level 5)
        "hatchback": 4, "station wagon": 4, "minivan": 4, "van": 4, "jeep": 4,
        "racing car": 4, "formula 1": 4, "luxury car": 4,
        "scooter": 4, "moped": 4, "dirt bike": 4,
        "boat": 4, "yacht": 4, "sailboat": 4, "speedboat": 4,

        // Level 4-5: Specific flowers and plants
        "rose": 5, "tulip": 5, "sunflower": 5, "orchid": 5, "lily": 5, "daisy": 5,
        "bouquet": 4, "flower": 4, "floral": 4,
        
        // Level 3-4: Landscape features
        "mountain": 4, "mountains": 4, "hill": 4, "hills": 4,
        "beach": 4, "ocean": 4, "sea": 4, "lake": 4, "river": 4, "water": 3,
        "forest": 4, "woods": 4, "trees": 3,
        "sunset": 4, "sunrise": 4,
        "rock": 3, "rocks": 3, "stone": 3, "cliff": 4,

        // Level 3: Moderate specificity (these are useful, not generic!)
        "food": 3, "meal": 3, "cuisine": 3, "snack": 3, "beverage": 3, "drink": 3,
        "tableware": 3, "utensil": 3, "cutlery": 3, "silverware": 3, "dishware": 3,
        "animal": 3, "fish": 3,
        "vehicle": 3, "transport": 3, "transportation": 3,
        "building": 3, "house": 3, "structure": 3, "architecture": 3,

        // Level 2: Generic terms (still useful as fallback)
        "person": 2, "people": 2, "adult": 2, "human": 2, "individual": 2, "face": 2,
        "object": 2, "item": 2, "artifact": 2,
        "document": 2, "text": 2, "printed": 2,
        "clothing": 2, "suit": 2, "dress": 2,
        "scene": 2, "location": 2, "place": 2, "setting": 2,

        // Level 1: Very generic (last resort)
        "thing": 1, "stuff": 1, "material": 1,

        // Level 2: Scene/environment terms (useful for landscape/nature photos)
        "sky": 2, "blue sky": 3, "clouds": 2, "cloud": 2, "horizon": 2,
        "landscape": 3, "scenery": 2, "nature": 3, "environment": 2, "natural": 2,
        "outdoor": 2, "outside": 2, "field": 2,
        
        // Level 0: Background elements that should be filtered (moved from higher levels)
        // These commonly appear but rarely are the main subject
        "ground": 0, "land": 0, "wall": 0, "background": 0, "backdrop": 0,
        "plant": 0, "tree": 0, "grass": 0, "lawn": 0,  // Moved from level 2-3
        "foliage": 0, "greenery": 0, "vegetation": 0,  // Moved from level 2
        "palm tree": 0, "palm": 0, "trees in background": 0, "shrubbery": 0,
        "indoor": 0, "inside": 0  // Very generic scene terms
    ]

    /// Terms for clothing and accessories that should be filtered when a person is detected
    static let clothingAndAccessoryTerms: Set<String> = [
        "optical", "eyewear", "equipment",
        "shirt", "cloth", "wear", "garment", "apparel",
        "hat", "shoe", "accessory", "sunglasses", "glasses"
    ]

    // MARK: - Quality Thresholds

    /// Minimum sharpness score for "excellent" quality (0.0-1.0)
    static let excellentSharpnessThreshold: Double = 0.8

    /// Minimum exposure score for "proper" exposure (0.0-1.0)
    static let properExposureThreshold: Double = 0.7

    /// Minimum overall quality score for "excellent" (0.0-1.0)
    static let excellentQualityThreshold: Double = 0.8

    // MARK: - Purpose-Specific Quality Thresholds

    /// Portrait sharpness threshold for quality issues
    static let portraitSharpnessThreshold: Double = 0.5

    /// Portrait underexposed threshold
    static let portraitUnderexposedThreshold: Double = 0.35

    /// Portrait overexposed threshold
    static let portraitOverexposedThreshold: Double = 0.75

    /// Landscape/architecture sharpness threshold
    static let landscapeSharpnessThreshold: Double = 0.6

    /// Landscape minimum megapixels for print quality
    static let landscapeMinMegapixels: Double = 8.0

    /// Document text sharpness threshold for OCR
    static let documentSharpnessThreshold: Double = 0.4

    /// Document exposure minimum threshold
    static let documentExposureMin: Double = 0.4

    /// Document exposure maximum threshold
    static let documentExposureMax: Double = 0.7

    /// Product photo sharpness threshold
    static let productSharpnessThreshold: Double = 0.6

    /// Product minimum megapixels for e-commerce
    static let productMinMegapixels: Double = 4.0

    /// Food photography underexposed threshold
    static let foodUnderexposedThreshold: Double = 0.4

    /// Wildlife sharpness threshold
    static let wildlifeSharpnessThreshold: Double = 0.65

    /// General purpose sharpness threshold
    static let generalSharpnessThreshold: Double = 0.4

    /// General purpose underexposed threshold
    static let generalUnderexposedThreshold: Double = 0.3

    /// General purpose overexposed threshold
    static let generalOverexposedThreshold: Double = 0.8

    // MARK: - Overall Quality Calculation

    /// High quality image minimum megapixels
    static let highQualityMinMegapixels: Double = 12.0

    /// High quality image minimum dimension
    static let highQualityMinDimension: CGFloat = 2000

    /// Medium quality image minimum megapixels
    static let mediumQualityMinMegapixels: Double = 4.0

    /// Medium quality image minimum dimension
    static let mediumQualityMinDimension: CGFloat = 1200

    /// Low quality image minimum megapixels
    static let lowQualityMinMegapixels: Double = 2.0

    /// Weight for resolution in quality score calculation
    static let qualityResolutionWeight: Double = 0.3

    /// Weight for sharpness in quality score calculation
    static let qualitySharpnessWeight: Double = 0.4

    /// Weight for exposure in quality score calculation
    static let qualityExposureWeight: Double = 0.3

    /// Threshold for high quality tier
    static let highQualityScoreThreshold: Double = 0.75

    /// Threshold for medium quality tier
    static let mediumQualityScoreThreshold: Double = 0.45

    /// Optimal exposure value (midpoint)
    static let optimalExposure: Double = 0.5

    // MARK: - Analysis Progress

    /// Reserve factor for final processing (progress * this value)
    static let progressReserveFactor: Double = 0.9

    // MARK: - ML Caption

    /// Confidence threshold for preferring ML caption over standard
    static let mlCaptionConfidenceThreshold: Double = 0.7

    // MARK: - Color/Mood Thresholds

    /// Brightness threshold for "dark" mood (0.0-1.0)
    static let darkBrightnessThreshold: CGFloat = 0.15

    /// Brightness threshold for "bright" mood (0.0-1.0)
    static let brightBrightnessThreshold: CGFloat = 0.85

    /// Saturation threshold for "vibrant" mood (0.0-1.0)
    static let vibrantSaturationThreshold: CGFloat = 0.75

    /// Saturation threshold for "monochromatic" mood (0.0-1.0)
    static let monochromaticSaturationThreshold: CGFloat = 0.1

    // MARK: - Confidence Thresholds

    /// Minimum confidence for including a classification in results
    static let minimumClassificationConfidence: Float = 0.1

    /// Confidence threshold for low-signal detection in captions/narratives
    static let lowSignalConfidenceThreshold: Double = 0.20

    /// Confidence threshold for including subjects in captions
    static let captionSubjectConfidence: Double = 0.5

    /// Confidence threshold for high-specificity subjects in captions
    static let highSpecificityConfidenceThreshold: Double = 0.25

    /// Confidence threshold for medium-specificity subjects in captions
    static let mediumSpecificityConfidenceThreshold: Double = 0.35

    /// Confidence threshold for location context in captions
    static let locationContextConfidence: Float = 0.6

    /// Minimum confidence for background classification to be kept
    static let backgroundKeepConfidence: Float = 0.75

    // MARK: - Boost Factors

    /// Boost factor for person classifications when person detected
    static let personClassificationBoost: Float = 1.3

    /// Boost factor for vehicle classifications when vehicle detected
    static let vehicleClassificationBoost: Float = 1.3

    /// Boost factor for vehicles in subject detection
    static let vehicleSubjectBoost: Double = 2.5

    /// Boost factor for small vehicles with person present
    static let vehicleWithPersonSmallBoost: Double = 1.5

    /// Minimum vehicle area ratio to be considered primary subject (0.0-1.0)
    static let vehiclePrimaryAreaThreshold: Double = 0.15

    /// Boost for saliency overlap with detected objects
    static let saliencyOverlapBoostMax: Double = 0.3

    // MARK: - Limits

    /// Maximum number of primary subjects to detect
    static let maxPrimarySubjects = 3

    /// Maximum number of smart tags per image
    static let maxSmartTags = 12

    /// Maximum number of classifications to consider
    static let maxClassifications = 10

    /// Maximum number of faces to detect
    static let maxFaceDetections = 15

    /// Minimum image dimension for enhanced Vision analysis
    static let minEnhancedVisionDimension = 500

    /// Minimum megapixels for wallpaper use case suggestion
    static let wallpaperMinMegapixels: Double = 8.0

    // MARK: - Cache Settings

    /// Maximum number of cached analysis results
    static let maxCacheEntries = 20

    /// Current cache version - increment to invalidate cache
    static let cacheVersion = "v10"  // Incremented for CoreML integration and constants centralization

    // MARK: - Helper Functions

    /// Check if a term is clothing or accessory related
    static func isClothingOrAccessory(_ identifier: String) -> Bool {
        let lowercased = identifier.lowercased()
        return clothingAndAccessoryTerms.contains { lowercased.contains($0) }
    }

    /// Get specificity level for a classification (0-5, higher = more specific)
    /// Returns the specificity level, or a computed default based on term analysis
    static func getSpecificity(_ identifier: String) -> Int {
        let lowercased = identifier.lowercased()

        // Direct match
        if let specificity = specificityLevels[lowercased] {
            return specificity
        }

        // Partial match (e.g., "sports car, sport car" contains "sports car")
        for (term, level) in specificityLevels {
            if lowercased.contains(term) {
                return level
            }
        }

        // Default heuristics for unknown terms
        // Multi-word terms tend to be more specific
        let wordCount = lowercased.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        if wordCount >= 3 { return 4 }  // e.g., "red convertible sports car"
        if wordCount == 2 { return 3 }  // e.g., "red car"

        // Single-word unknown term - assume moderate specificity
        return 2
    }

    /// Calculate combined score for ranking: specificity × confidence
    static func calculateRankingScore(identifier: String, confidence: Float) -> Double {
        let specificity = Double(getSpecificity(identifier))
        return specificity * Double(confidence)
    }

    /// Check if a term is generic (backward compatibility - now checks specificity ≤ 2)
    static func isGeneric(_ identifier: String) -> Bool {
        return getSpecificity(identifier) <= 2
    }

    /// Check if a term is background element (backward compatibility - now checks specificity == 0)
    static func isBackground(_ identifier: String) -> Bool {
        return getSpecificity(identifier) == 0
    }

    /// Check if a term is specific enough to be useful (specificity ≥ 3)
    static func isSpecific(_ identifier: String) -> Bool {
        return getSpecificity(identifier) >= 3
    }
}

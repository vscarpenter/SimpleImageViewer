import Foundation

/// One mutually-exclusive view mode for the viewer window (Studio redesign).
/// Replaces the previous normal/thumbnailStrip/grid cases plus independent
/// panel booleans with a single source of truth.
enum ViewMode: String, CaseIterable {
    case single
    case strip
    case grid

    /// Accepts current and legacy (pre-Studio) persisted raw values, so saved
    /// window state from older versions restores correctly.
    init?(rawValue: String) {
        switch rawValue {
        case "single", "normal":
            self = .single
        case "strip", "thumbnailStrip":
            self = .strip
        case "grid":
            self = .grid
        default:
            return nil
        }
    }

    /// Filmstrip is docked in Single and Strip; Grid replaces stage + filmstrip.
    var showsFilmstrip: Bool {
        self != .grid
    }

    var displayName: String {
        switch self {
        case .single:
            return "Single"
        case .strip:
            return "Strip"
        case .grid:
            return "Grid"
        }
    }

    var icon: String {
        switch self {
        case .single:
            return "photo"
        case .strip:
            return "rectangle.grid.1x2"
        case .grid:
            return "square.grid.3x3"
        }
    }

    /// T key: Strip toggles back to Single; from anywhere else it forces Strip.
    func togglingStrip() -> ViewMode {
        self == .strip ? .single : .strip
    }

    /// G key: Grid toggles back to Single; from anywhere else it enters Grid.
    func togglingGrid() -> ViewMode {
        self == .grid ? .single : .grid
    }

    /// Esc steps out one level. `nil` means Esc changes nothing — it must still
    /// be consumed by the caller so it never falls through to "exit folder";
    /// only Back/breadcrumb leaves the folder.
    var afterEscape: ViewMode? {
        switch self {
        case .grid, .strip:
            return .single
        case .single:
            return nil
        }
    }
}

/// Tabs of the docked inspector panel (Studio redesign).
enum InspectorTab: String {
    case info
    case insights
}

/// Sort orders offered by the grid toolbar's sort menu (finding U10).
/// Comparison over ImageFile lives with the view model; this stays pure.
enum ImageSortOrder: String, CaseIterable {
    case name
    case dateCaptured
    case dateModified
    case size

    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .dateCaptured:
            return "Date Captured"
        case .dateModified:
            return "Date Modified"
        case .size:
            return "Size"
        }
    }
}

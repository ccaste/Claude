import Foundation

// The kinds of work that go on a quote. Each carries sensible defaults that the
// user can override globally (Defaults tab) or per quote.
enum ItemType: String, Codable, CaseIterable, Identifiable {
    case roofline, roof_ridge, ground_lights, bushes, tree_wrap, tree_canopy, edges, wreaths, garland, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .roofline:     return "Roofline"
        case .roof_ridge:   return "Roof Ridges"
        case .ground_lights:return "Ground Lights"
        case .bushes:       return "Bushes"
        case .tree_wrap:    return "Tree Wrapping"
        case .tree_canopy:  return "Tree Canopy"
        case .edges:        return "Edges"
        case .wreaths:      return "Wreaths"
        case .garland:      return "Garland"
        case .other:        return "Other"
        }
    }

    var icon: String {
        switch self {
        case .roofline, .roof_ridge, .edges: return "house"
        case .ground_lights:                 return "light.beacon.max"
        case .bushes:                        return "leaf"
        case .tree_wrap, .tree_canopy:       return "tree"
        case .wreaths:                       return "circle.circle"
        case .garland:                       return "scribble"
        case .other:                         return "sparkles"
        }
    }

    var defaultLight: LightType {
        switch self {
        case .bushes, .tree_wrap, .tree_canopy: return .mini
        case .wreaths, .garland:                return .none
        default:                                return .c9
        }
    }

    // Wreaths/garland are always sold by count; everything else follows the
    // light type (C9/C7 by the foot, mini by the set).
    func unit(for light: LightType) -> String {
        switch self {
        case .wreaths: return "each"
        case .garland: return "9ft section"
        default:
            switch light {
            case .c7, .c9: return "ft"
            case .mini:    return "set"
            case .none:    return "each"
            }
        }
    }

    // Which light types make sense for this item.
    var lightOptions: [LightType] {
        (self == .wreaths || self == .garland) ? [.c9, .c7, .mini, .none] : [.c9, .c7, .mini]
    }

    static let defaultColor = "Warm White"
    var sortOrder: Int { ItemType.allCases.firstIndex(of: self) ?? 0 }
}

enum LightType: String, Codable, CaseIterable {
    case mini, c7, c9, none
    var label: String {
        switch self {
        case .mini: return "Mini"
        case .c7:   return "C7"
        case .c9:   return "C9"
        case .none: return "None"
        }
    }

    var byFoot: Bool { self == .c7 || self == .c9 }

    // Spacing depends on the light type, not the item.
    var spacingOptions: [String] {
        switch self {
        case .c7, .c9: return ["6 inch", "9 inch", "12 inch", "15 inch", "18 inch", "24 inch", "36 inch"]
        case .mini:    return ["3 inch", "4 inch", "6 inch"]
        case .none:    return []
        }
    }

    var defaultSpacing: String? {
        switch self {
        case .c7, .c9: return "12 inch"
        case .mini:    return "4 inch"
        case .none:    return nil
        }
    }
}

// A row in the per-org defaults table — one per (item type, light type).
struct ItemDefault: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var item_type: ItemType
    var light_type: LightType?
    var label: String
    var default_color: String?
    var default_spacing: String?
    var default_unit: String
    var default_unit_price: Double
    var sort: Int
}

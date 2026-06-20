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

    // Sensible starting unit / light / color used when seeding the defaults.
    var defaultUnit: String {
        switch self {
        case .roofline, .roof_ridge, .edges: return "ft"
        case .garland:                       return "9ft section"
        default:                             return "each"
        }
    }

    var defaultLight: LightType {
        switch self {
        case .bushes, .tree_wrap, .tree_canopy: return .mini
        case .wreaths, .garland:                return .none
        default:                                return .c9
        }
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
}

// A row in the per-org defaults table.
struct ItemDefault: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var item_type: ItemType
    var label: String
    var default_light_type: LightType?
    var default_color: String?
    var default_unit: String
    var default_unit_price: Double
    var sort: Int
}

import Foundation

// Christmas-lighting domain models (Phase 2).

enum PricingUnit: String, Codable, CaseIterable {
    case linear_ft, strand, section_9ft, each

    var label: String {
        switch self {
        case .linear_ft:  return "Per linear foot"
        case .strand:     return "Per strand"
        case .section_9ft:return "Per 9 ft section"
        case .each:       return "Per unit"
        }
    }

    // Short label shown next to a quantity, e.g. "120 ft".
    var abbrev: String {
        switch self {
        case .linear_ft:  return "ft"
        case .strand:     return "strands"
        case .section_9ft:return "× 9ft"
        case .each:       return "ea"
        }
    }

    // Hint for what the quantity means when adding a section.
    var quantityPrompt: String {
        switch self {
        case .linear_ft:  return "Linear feet"
        case .strand:     return "Number of strands"
        case .section_9ft:return "Number of 9 ft sections"
        case .each:       return "Quantity"
        }
    }
}

enum DesignStatus: String, Codable, CaseIterable {
    case draft, quoted, active, archived
    var label: String { rawValue.capitalized }
}

enum MaterialStatus: String, Codable, CaseIterable {
    case in_storage, installed, returned_to_customer
    var label: String {
        switch self {
        case .in_storage:           return "In Storage"
        case .installed:            return "Installed"
        case .returned_to_customer: return "Returned to Customer"
        }
    }
}

// Preset categories for the price book / design sections.
enum ProductCategory: String, CaseIterable {
    case roofline, tree_wrap, wreath, garland, pathway, accent, other
    var label: String {
        switch self {
        case .tree_wrap: return "Tree / Bush Wrap"
        default:         return rawValue.capitalized
        }
    }
}

struct CatalogItem: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var name: String
    var category: String
    var pricing_unit: PricingUnit
    var unit_price: Double
    var bulb_type: String?
    var color: String?
    var size: String?
    var spacing: String?
    var active: Bool
    var notes: String?
}

struct Design: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var property_id: UUID
    var job_id: UUID?
    var season_year: Int
    var status: DesignStatus
    var notes: String?
}

struct DesignSection: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var design_id: UUID
    var catalog_id: UUID?
    var label: String
    var product_name: String
    var pricing_unit: PricingUnit
    var quantity: Double
    var unit_price: Double
    var bulb_type: String?
    var color: String?
    var power_circuit: String?
    var notes: String?
    var sort: Int

    var lineTotal: Double { quantity * unit_price }
}

// Minimal Quote shape used when generating from a design.
struct InsertedID: Decodable { let id: UUID }

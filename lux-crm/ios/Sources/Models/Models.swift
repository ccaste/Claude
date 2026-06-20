import Foundation

// Domain models. Property names use snake_case to match the Postgres columns so
// they decode directly from Supabase/PostgREST JSON without custom CodingKeys.

enum UserRole: String, Codable, CaseIterable { case owner, admin, crew }

enum ServiceType: String, Codable, CaseIterable {
    case christmas_lighting, landscape_lighting, maintenance, repair, other

    var label: String {
        switch self {
        case .christmas_lighting: return "Christmas Lighting"
        case .landscape_lighting: return "Landscape Lighting"
        case .maintenance:        return "Maintenance"
        case .repair:             return "Repair"
        case .other:              return "Other"
        }
    }
}

enum JobStatus: String, Codable, CaseIterable {
    case lead, quoted, approved, scheduled, in_progress, completed, on_hold, cancelled

    var label: String {
        switch self {
        case .in_progress: return "In Progress"
        case .on_hold:     return "On Hold"
        default:           return rawValue.capitalized
        }
    }
}

enum VisitKind: String, Codable, CaseIterable {
    case consult, install, service, maintenance, removal
    var label: String { rawValue.capitalized }
}

enum VisitStatus: String, Codable, CaseIterable {
    case unscheduled, scheduled, en_route, in_progress, completed, skipped
    var label: String {
        switch self {
        case .en_route:    return "En Route"
        case .in_progress: return "In Progress"
        default:           return rawValue.capitalized
        }
    }
}

enum QuoteStatus: String, Codable, CaseIterable { case draft, sent, approved, declined, expired }
enum InvoiceStatus: String, Codable, CaseIterable { case draft, sent, partial, paid, overdue, void }

struct Organization: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var timezone: String
}

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var full_name: String
    var role: UserRole
    var phone: String?
    var active: Bool
}

struct Client: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var name: String
    var company: String?
    var email: String?
    var phone: String?
    var billing_line1: String?
    var billing_line2: String?
    var billing_city: String?
    var billing_state: String?
    var billing_zip: String?
    var source: String?
    var notes: String?
    var archived: Bool
    var created_at: Date?
}

struct Property: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var client_id: UUID
    var label: String
    var line1: String?
    var line2: String?
    var city: String?
    var state: String?
    var zip: String?
    var latitude: Double?
    var longitude: Double?
    var stories: Int?
    var access_notes: String?
    var power_notes: String?
    var notes: String?

    var oneLineAddress: String {
        [line1, city, state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct Fixture: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var property_id: UUID
    var category: String
    var description: String?
    var quantity: Double
    var unit: String?
    var wattage: Double?
    var location: String?
    var owned_by_client: Bool
    var in_storage: Bool
    var installed_year: Int?
    var notes: String?
}

struct Job: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var client_id: UUID
    var property_id: UUID?
    var title: String
    var service_type: ServiceType
    var status: JobStatus
    var season_year: Int?
    var is_recurring: Bool
    var description: String?
    var created_at: Date?
}

struct Visit: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var job_id: UUID
    var kind: VisitKind
    var status: VisitStatus
    var assigned_to: UUID?
    var scheduled_start: Date?
    var scheduled_end: Date?
    var completed_at: Date?
    var notes: String?
}

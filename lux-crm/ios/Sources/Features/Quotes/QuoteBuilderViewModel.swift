import Foundation
import Supabase

// One editable line on the quote.
struct QuoteItemDraft: Identifiable {
    let id = UUID()
    var itemType: ItemType
    var area: String = ""
    var lightType: LightType
    var color: String
    var quantity: Double = 0
    var unit: String
    var unitPrice: Double
    var spacing: String?

    var lineTotal: Double { quantity * unitPrice }

    var summary: String {
        var parts: [String] = []
        if !area.isEmpty { parts.append(area) }
        if lightType != .none { parts.append(lightType.label) }
        if !color.isEmpty && color != "None" { parts.append(color) }
        if let s = spacing, !s.isEmpty { parts.append(s) }
        return parts.joined(separator: " · ")
    }
}

@MainActor
final class QuoteBuilderViewModel: ObservableObject {
    @Published var items: [QuoteItemDraft] = []
    @Published var saving = false
    @Published var savedQuote: Quote?
    @Published var errorMessage: String?

    // Keyed by "itemType|lightType".
    private var defaults: [String: ItemDefault] = [:]

    let property: Property
    let job: Job?

    init(property: Property, job: Job?) {
        self.property = property
        self.job = job
    }

    var total: Double { items.reduce(0) { $0 + $1.lineTotal } }

    private static func key(_ item: ItemType, _ light: LightType) -> String {
        "\(item.rawValue)|\(light.rawValue)"
    }

    func defaultFor(_ item: ItemType, _ light: LightType) -> ItemDefault? {
        defaults[Self.key(item, light)]
    }

    func loadDefaults(orgID: UUID) async {
        let rows = await ItemDefaultsStore.loadAndSeed(orgID: orgID)
        defaults = Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            row.light_type.map { (Self.key(row.item_type, $0), row) }
        })
    }

    // Add an item, pre-filled from the saved defaults for its default light type.
    func addItem(_ type: ItemType) {
        let light = type.defaultLight
        let d = defaultFor(type, light)
        items.append(QuoteItemDraft(
            itemType: type,
            lightType: light,
            color: d?.default_color ?? ItemType.defaultColor,
            unit: type.unit(for: light),
            unitPrice: d?.default_unit_price ?? 0,
            spacing: d?.default_spacing ?? light.defaultSpacing))
    }

    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets) }

    func replace(_ item: QuoteItemDraft) {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
    }

    func saveQuote(orgID: UUID) async {
        saving = true
        defer { saving = false }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let number = "Q-\(Int(Date().timeIntervalSince1970))"
        let subtotal = total
        let clientID = property.client_id
        let propertyID = property.id
        let jobID = job?.id
        let wasLead = job?.status == .lead

        struct NewQuote: Encodable {
            let org_id: UUID; let client_id: UUID; let property_id: UUID; let job_id: UUID?
            let number: String; let status: String; let issued_at: String
            let subtotal: Double; let tax: Double; let total: Double
        }
        struct NewItem: Encodable {
            let quote_id: UUID; let item_type: ItemType; let area: String?
            let light_type: LightType; let color: String?; let spacing: String?
            let description: String; let quantity: Double; let unit: String
            let unit_price: Double; let taxable: Bool; let sort: Int
        }
        do {
            let inserted: [InsertedID] = try await supabase.from("quotes")
                .insert(NewQuote(org_id: orgID, client_id: clientID, property_id: propertyID,
                                 job_id: jobID, number: number, status: "draft",
                                 issued_at: df.string(from: Date()),
                                 subtotal: subtotal, tax: 0, total: subtotal))
                .select("id").execute().value
            guard let quoteID = inserted.first?.id else { return }

            let payload = items.enumerated().map { idx, it in
                NewItem(quote_id: quoteID, item_type: it.itemType, area: it.area.nilIfEmpty,
                        light_type: it.lightType, color: it.color.nilIfEmpty, spacing: it.spacing,
                        description: "\(it.itemType.label)\(it.area.isEmpty ? "" : " – \(it.area)")",
                        quantity: it.quantity, unit: it.unit, unit_price: it.unitPrice,
                        taxable: true, sort: idx)
            }
            if !payload.isEmpty {
                try await supabase.from("quote_line_items").insert(payload).execute()
            }
            if let jobID, wasLead {
                try await supabase.from("jobs").update(["status": "quoted"])
                    .eq("id", value: jobID).execute()
            }
            let made: [Quote] = (try? await supabase.from("quotes").select()
                .eq("id", value: quoteID).limit(1).execute().value) ?? []
            savedQuote = made.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Shared loader/seeder so the quote builder and Defaults tab stay in sync.
enum ItemDefaultsStore {
    struct NewDefault: Encodable {
        let org_id: UUID; let item_type: ItemType; let light_type: LightType; let label: String
        let default_color: String; let default_spacing: String?; let default_unit: String
        let default_unit_price: Double; let sort: Int
    }

    static func loadAndSeed(orgID: UUID) async -> [ItemDefault] {
        var rows: [ItemDefault] = (try? await supabase.from("item_defaults")
            .select().eq("org_id", value: orgID).execute().value) ?? []

        // Insert any missing (item type, light type) combinations.
        let have = Set(rows.compactMap { r in r.light_type.map { "\(r.item_type.rawValue)|\($0.rawValue)" } })
        var missing: [NewDefault] = []
        var sort = 0
        for item in ItemType.allCases {
            for light in item.lightOptions {
                defer { sort += 1 }
                let key = "\(item.rawValue)|\(light.rawValue)"
                guard !have.contains(key) else { continue }
                missing.append(NewDefault(
                    org_id: orgID, item_type: item, light_type: light,
                    label: item.label, default_color: ItemType.defaultColor,
                    default_spacing: light.defaultSpacing, default_unit: item.unit(for: light),
                    default_unit_price: 0, sort: sort))
            }
        }
        if !missing.isEmpty {
            let added: [ItemDefault] = (try? await supabase.from("item_defaults")
                .insert(missing).select().execute().value) ?? []
            rows.append(contentsOf: added)
        }
        return rows
    }
}

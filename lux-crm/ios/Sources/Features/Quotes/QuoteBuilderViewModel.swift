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

    var lineTotal: Double { quantity * unitPrice }

    var summary: String {
        var parts = [lightType.label, color].filter { !$0.isEmpty && $0 != "None" }
        if !area.isEmpty { parts.insert(area, at: 0) }
        return parts.joined(separator: " · ")
    }
}

@MainActor
final class QuoteBuilderViewModel: ObservableObject {
    @Published var items: [QuoteItemDraft] = []
    @Published var defaults: [ItemType: ItemDefault] = [:]
    @Published var saving = false
    @Published var savedQuoteNumber: String?
    @Published var errorMessage: String?

    let property: Property
    let job: Job?

    init(property: Property, job: Job?) {
        self.property = property
        self.job = job
    }

    var total: Double { items.reduce(0) { $0 + $1.lineTotal } }

    func loadDefaults(orgID: UUID) async {
        var rows: [ItemDefault] = (try? await supabase.from("item_defaults")
            .select().eq("org_id", value: orgID).execute().value) ?? []
        if rows.isEmpty {
            rows = await seedDefaults(orgID: orgID)
        }
        defaults = Dictionary(uniqueKeysWithValues: rows.map { ($0.item_type, $0) })
    }

    // First run: create a default row per item type from the built-in starting values.
    private func seedDefaults(orgID: UUID) async -> [ItemDefault] {
        struct NewDefault: Encodable {
            let org_id: UUID; let item_type: ItemType; let label: String
            let default_light_type: LightType; let default_color: String
            let default_unit: String; let default_unit_price: Double; let sort: Int
        }
        let payload = ItemType.allCases.map {
            NewDefault(org_id: orgID, item_type: $0, label: $0.label,
                       default_light_type: $0.defaultLight, default_color: ItemType.defaultColor,
                       default_unit: $0.defaultUnit, default_unit_price: 0, sort: $0.sortOrder)
        }
        let inserted: [ItemDefault] = (try? await supabase.from("item_defaults")
            .insert(payload).select().execute().value) ?? []
        return inserted
    }

    // Add an item to the quote, pre-filled from the saved defaults.
    func addItem(_ type: ItemType) {
        let d = defaults[type]
        items.append(QuoteItemDraft(
            itemType: type,
            lightType: d?.default_light_type ?? type.defaultLight,
            color: d?.default_color ?? ItemType.defaultColor,
            unit: d?.default_unit ?? type.defaultUnit,
            unitPrice: d?.default_unit_price ?? 0))
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

        struct NewQuote: Encodable {
            let org_id: UUID; let client_id: UUID; let property_id: UUID; let job_id: UUID?
            let number: String; let status: String; let issued_at: String
            let subtotal: Double; let tax: Double; let total: Double
        }
        struct NewItem: Encodable {
            let quote_id: UUID; let item_type: ItemType; let area: String?
            let light_type: LightType; let color: String?; let description: String
            let quantity: Double; let unit: String; let unit_price: Double
            let taxable: Bool; let sort: Int
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
                        light_type: it.lightType, color: it.color.nilIfEmpty,
                        description: "\(it.itemType.label)\(it.area.isEmpty ? "" : " – \(it.area)")",
                        quantity: it.quantity, unit: it.unit, unit_price: it.unitPrice,
                        taxable: true, sort: idx)
            }
            if !payload.isEmpty {
                try await supabase.from("quote_line_items").insert(payload).execute()
            }
            // If this quote is for a lead still in 'lead', move it to 'quoted'.
            if let jobID, job?.status == .lead {
                try await supabase.from("jobs").update(["status": "quoted"])
                    .eq("id", value: jobID).execute()
            }
            savedQuoteNumber = number
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import Foundation
import Supabase

@MainActor
final class DesignViewModel: ObservableObject {
    @Published var sections: [DesignSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastQuoteNumber: String?

    var total: Double { sections.reduce(0) { $0 + $1.lineTotal } }

    func load(designID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            sections = try await supabase
                .from("design_sections")
                .select()
                .eq("design_id", value: designID)
                .order("sort")
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSection(_ draft: SectionDraft, design: Design, orgID: UUID) async {
        struct NewSection: Encodable {
            let org_id: UUID
            let design_id: UUID
            let catalog_id: UUID?
            let label: String
            let product_name: String
            let pricing_unit: PricingUnit
            let quantity: Double
            let unit_price: Double
            let bulb_type: String?
            let color: String?
            let power_circuit: String?
            let notes: String?
            let sort: Int
        }
        do {
            let inserted: [DesignSection] = try await supabase
                .from("design_sections")
                .insert(NewSection(
                    org_id: orgID, design_id: design.id, catalog_id: draft.catalog?.id,
                    label: draft.label, product_name: draft.productName,
                    pricing_unit: draft.pricingUnit, quantity: draft.quantity,
                    unit_price: draft.unitPrice, bulb_type: draft.catalog?.bulb_type,
                    color: draft.catalog?.color, power_circuit: draft.powerCircuit.nilIfEmpty,
                    notes: draft.notes.nilIfEmpty, sort: sections.count))
                .select()
                .execute()
                .value
            if let new = inserted.first { sections.append(new) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ section: DesignSection) async {
        do {
            try await supabase.from("design_sections").delete().eq("id", value: section.id).execute()
            sections.removeAll { $0.id == section.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Turn the design into a draft quote with one line per section.
    func generateQuote(design: Design, property: Property, orgID: UUID) async {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())
        let number = "Q-\(Int(Date().timeIntervalSince1970))"
        let subtotal = total

        struct NewQuote: Encodable {
            let org_id: UUID; let client_id: UUID; let property_id: UUID?
            let number: String; let status: String; let issued_at: String
            let subtotal: Double; let tax: Double; let total: Double
        }
        struct NewItem: Encodable {
            let quote_id: UUID; let description: String
            let quantity: Double; let unit_price: Double; let taxable: Bool; let sort: Int
        }
        do {
            let inserted: [InsertedID] = try await supabase
                .from("quotes")
                .insert(NewQuote(
                    org_id: orgID, client_id: property.client_id, property_id: property.id,
                    number: number, status: "draft", issued_at: today,
                    subtotal: subtotal, tax: 0, total: subtotal))
                .select("id")
                .execute()
                .value
            guard let quoteID = inserted.first?.id else { return }

            let items = sections.enumerated().map { idx, s in
                NewItem(quote_id: quoteID,
                        description: "\(s.label) — \(s.product_name) (\(s.quantity.trimmed) \(s.pricing_unit.abbrev))",
                        quantity: s.quantity, unit_price: s.unit_price, taxable: true, sort: idx)
            }
            try await supabase.from("quote_line_items").insert(items).execute()
            try await supabase.from("designs").update(["status": "quoted"]).eq("id", value: design.id).execute()
            lastQuoteNumber = number
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SectionDraft {
    var catalog: CatalogItem?
    var label = ""
    var productName = ""
    var pricingUnit = PricingUnit.each
    var quantity = 0.0
    var unitPrice = 0.0
    var powerCircuit = ""
    var notes = ""
}

import Foundation
import Supabase

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var items: [CatalogItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await supabase
                .from("product_catalog")
                .select()
                .eq("active", value: true)
                .order("category")
                .order("name")
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(_ draft: CatalogDraft, orgID: UUID) async {
        struct NewItem: Encodable {
            let org_id: UUID
            let name: String
            let category: String
            let pricing_unit: PricingUnit
            let unit_price: Double
            let bulb_type: String?
            let color: String?
            let size: String?
            let spacing: String?
        }
        do {
            let inserted: [CatalogItem] = try await supabase
                .from("product_catalog")
                .insert(NewItem(
                    org_id: orgID, name: draft.name, category: draft.category,
                    pricing_unit: draft.pricingUnit, unit_price: draft.unitPrice,
                    bulb_type: draft.bulbType.nilIfEmpty, color: draft.color.nilIfEmpty,
                    size: draft.size.nilIfEmpty, spacing: draft.spacing.nilIfEmpty))
                .select()
                .execute()
                .value
            if let new = inserted.first { items.append(new) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Plain form state for the add-item sheet.
struct CatalogDraft {
    var name = ""
    var category = ProductCategory.roofline.rawValue
    var pricingUnit = PricingUnit.linear_ft
    var unitPrice = 0.0
    var bulbType = ""
    var color = ""
    var size = ""
    var spacing = ""
}

extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}

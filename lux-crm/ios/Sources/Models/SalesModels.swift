import Foundation

// Quote / invoice / payment models used by the job lifecycle screens.
// Date-typed `date` columns (issued_at, due_at) are decoded as String to avoid
// date-only parsing issues; timestamptz columns decode fine as Date elsewhere.

struct Quote: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var client_id: UUID
    var property_id: UUID?
    var job_id: UUID?
    var number: String
    var status: QuoteStatus
    var issued_at: String?
    var subtotal: Double
    var tax: Double
    var total: Double
    var deposit_required: Bool?
    var deposit_amount: Double?
}

struct Invoice: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var client_id: UUID
    var job_id: UUID?
    var quote_id: UUID?
    var number: String
    var status: InvoiceStatus
    var issued_at: String?
    var due_at: String?
    var subtotal: Double
    var tax: Double
    var total: Double
    var amount_paid: Double
    var deposit_amount: Double?

    var balance: Double { max(total - amount_paid, 0) }
}

struct Payment: Codable, Identifiable, Hashable {
    let id: UUID
    var org_id: UUID
    var invoice_id: UUID
    var amount: Double
    var method: String
    var notes: String?
}

struct LineItem: Codable, Identifiable, Hashable {
    let id: UUID
    var description: String
    var quantity: Double
    var unit_price: Double
    var taxable: Bool
    var sort: Int
    var item_type: ItemType?
    var area: String?
    var light_type: LightType?
    var color: String?
    var unit: String?

    var lineTotal: Double { quantity * unit_price }
}

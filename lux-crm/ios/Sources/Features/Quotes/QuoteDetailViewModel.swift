import Foundation
import Supabase

@MainActor
final class QuoteDetailViewModel: ObservableObject {
    @Published var quote: Quote
    @Published var lineItems: [LineItem] = []
    @Published var client: Client?
    @Published var createdJob: Job?
    @Published var working = false
    @Published var errorMessage: String?

    init(quote: Quote) { self.quote = quote }

    var clientName: String { client?.name ?? "" }
    var clientEmail: String? { client?.email?.nilIfEmpty }
    var clientPhone: String? { client?.phone?.nilIfEmpty }

    func load() async {
        let quoteID = quote.id
        let clientID = quote.client_id
        lineItems = (try? await supabase.from("quote_line_items").select()
            .eq("quote_id", value: quoteID).order("sort").execute().value) ?? []
        let clients: [Client] = (try? await supabase.from("clients").select()
            .eq("id", value: clientID).limit(1).execute().value) ?? []
        client = clients.first
    }

    // Customer-facing summary used for email/text.
    func messageBody() -> String {
        var lines = ["Hi \(clientName.isEmpty ? "there" : clientName),",
                     "", "Here's your lighting quote from LUX Lighting Services (\(quote.number)):", ""]
        for it in lineItems {
            lines.append("• \(it.description) — \(it.quantity.trimmed) \(it.unit ?? "") × \(it.unit_price.usd) = \(it.lineTotal.usd)")
        }
        lines.append("")
        lines.append("Total: \(quote.total.usd)")
        if let dep = quote.deposit_amount, dep > 0 { lines.append("Deposit to reserve: \(dep.usd)") }
        lines.append("")
        lines.append("Reply to accept, request changes, or with any questions. Thank you!")
        return lines.joined(separator: "\n")
    }

    func setDeposit(_ amount: Double) async {
        struct DepositUpdate: Encodable { let deposit_required: Bool; let deposit_amount: Double }
        do {
            try await supabase.from("quotes")
                .update(DepositUpdate(deposit_required: amount > 0, deposit_amount: amount))
                .eq("id", value: quote.id).execute()
            quote.deposit_required = amount > 0
            quote.deposit_amount = amount
        } catch { errorMessage = error.localizedDescription }
    }

    func markSent(channel: String, body: String) async {
        struct NewMessage: Encodable {
            let org_id: UUID; let client_id: UUID?; let channel: String
            let direction: String; let body: String; let status: String; let sent_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        try? await supabase.from("messages").insert(NewMessage(
            org_id: quote.org_id, client_id: quote.client_id, channel: channel,
            direction: "outbound", body: body, status: "sent", sent_at: now)).execute()
        if quote.status == .draft {
            try? await supabase.from("quotes").update(["status": "sent"])
                .eq("id", value: quote.id).execute()
            quote.status = .sent
        }
    }

    func requestChanges() async {
        await updateStatus("changes_requested")
        quote.status = .changes_requested
    }

    func decline() async {
        await updateStatus("declined")
        quote.status = .declined
        if let jobID = quote.job_id {
            try? await supabase.from("jobs").update(["status": "declined"])
                .eq("id", value: jobID).execute()
        }
    }

    private func updateStatus(_ s: String) async {
        try? await supabase.from("quotes").update(["status": s]).eq("id", value: quote.id).execute()
    }

    // Accept: a job is created from the quote (or the originating request becomes
    // the job), then an invoice is created from it, and items move into storage.
    func accept() async {
        working = true
        defer { working = false }
        do {
            try await supabase.from("quotes").update(["status": "approved"])
                .eq("id", value: quote.id).execute()
            quote.status = .approved

            // Resolve the job: reuse the request's record, or create one.
            let jobID: UUID
            if let existing = quote.job_id {
                try await supabase.from("jobs").update(["status": "approved"])
                    .eq("id", value: existing).execute()
                jobID = existing
            } else {
                struct NewJob: Encodable {
                    let org_id: UUID; let client_id: UUID; let property_id: UUID?
                    let title: String; let service_type: String; let status: String; let season_year: Int
                }
                let made: [InsertedID] = try await supabase.from("jobs").insert(NewJob(
                    org_id: quote.org_id, client_id: quote.client_id, property_id: quote.property_id,
                    title: "Christmas \(String(SeasonYear.current))", service_type: "christmas_lighting",
                    status: "approved", season_year: SeasonYear.current)).select("id").execute().value
                guard let newID = made.first?.id else { return }
                jobID = newID
                try? await supabase.from("quotes").update(JobLink(job_id: jobID))
                    .eq("id", value: quote.id).execute()
            }
            try await createInvoice(jobID: jobID)
            await createStorage()

            let jobs: [Job] = (try? await supabase.from("jobs").select()
                .eq("id", value: jobID).limit(1).execute().value) ?? []
            createdJob = jobs.first
        } catch { errorMessage = error.localizedDescription }
    }

    private func createInvoice(jobID: UUID) async throws {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let number = "INV-\(Int(Date().timeIntervalSince1970))"
        struct NewInvoice: Encodable {
            let org_id: UUID; let client_id: UUID; let job_id: UUID; let quote_id: UUID
            let number: String; let status: String; let issued_at: String
            let subtotal: Double; let tax: Double; let total: Double; let deposit_amount: Double
        }
        let made: [InsertedID] = try await supabase.from("invoices").insert(NewInvoice(
            org_id: quote.org_id, client_id: quote.client_id, job_id: jobID, quote_id: quote.id,
            number: number, status: "sent", issued_at: df.string(from: Date()),
            subtotal: quote.subtotal, tax: quote.tax, total: quote.total,
            deposit_amount: quote.deposit_amount ?? 0)).select("id").execute().value
        guard let invID = made.first?.id, !lineItems.isEmpty else { return }
        let items = lineItems.enumerated().map { idx, l in
            NewInvoiceItem(invoice_id: invID, item_type: l.item_type, area: l.area,
                           light_type: l.light_type, color: l.color, spacing: l.spacing,
                           description: l.description, quantity: l.quantity, unit: l.unit,
                           unit_price: l.unit_price, taxable: l.taxable, sort: idx)
        }
        try await supabase.from("invoice_line_items").insert(items).execute()
    }

    private func createStorage() async {
        guard let propertyID = quote.property_id, !lineItems.isEmpty else { return }
        let stored = lineItems.map { l in
            NewStored(org_id: quote.org_id, property_id: propertyID,
                      category: l.item_type?.rawValue ?? "other", description: l.description,
                      quantity: l.quantity, unit: l.unit, item_type: l.item_type, area: l.area,
                      light_type: l.light_type, color: l.color, spacing: l.spacing,
                      owned_by_client: true, status: "in_storage")
        }
        try? await supabase.from("fixtures").insert(stored).execute()
    }
}

private struct JobLink: Encodable { let job_id: UUID }
private struct NewInvoiceItem: Encodable {
    let invoice_id: UUID; let item_type: ItemType?; let area: String?
    let light_type: LightType?; let color: String?; let spacing: String?; let description: String
    let quantity: Double; let unit: String?; let unit_price: Double; let taxable: Bool; let sort: Int
}
private struct NewStored: Encodable {
    let org_id: UUID; let property_id: UUID; let category: String; let description: String
    let quantity: Double; let unit: String?; let item_type: ItemType?; let area: String?
    let light_type: LightType?; let color: String?; let spacing: String?
    let owned_by_client: Bool; let status: String
}

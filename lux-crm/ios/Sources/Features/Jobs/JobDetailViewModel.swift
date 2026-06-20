import Foundation
import Supabase

@MainActor
final class JobDetailViewModel: ObservableObject {
    @Published var job: Job
    @Published var visits: [Visit] = []
    @Published var quotes: [Quote] = []
    @Published var invoice: Invoice?
    @Published var payments: [Payment] = []
    @Published var errorMessage: String?

    init(job: Job) { self.job = job }

    var appointments: [Visit] { visits.filter { $0.kind == .consult } }
    var workVisits: [Visit] { visits.filter { $0.kind != .consult } }

    func load() async {
        // Copy actor-isolated values into locals so the parallel `async let`
        // autoclosures don't reference `self.job` from a nonisolated context.
        let jobID = job.id
        let propertyID = job.property_id ?? job.id

        async let v: [Visit] = (try? await supabase.from("visits").select()
            .eq("job_id", value: jobID).order("scheduled_start").execute().value) ?? []
        // Quotes are generated from the property's design, so match on property.
        async let q: [Quote] = (try? await supabase.from("quotes").select()
            .eq("property_id", value: propertyID)
            .order("created_at", ascending: false).execute().value) ?? []
        async let inv: [Invoice] = (try? await supabase.from("invoices").select()
            .eq("job_id", value: jobID).order("created_at", ascending: false)
            .limit(1).execute().value) ?? []
        visits = await v
        quotes = await q
        invoice = await inv.first
        await loadPayments()
    }

    private func loadPayments() async {
        guard let invoiceID = invoice?.id else { payments = []; return }
        payments = (try? await supabase.from("payments").select()
            .eq("invoice_id", value: invoiceID).order("paid_at").execute().value) ?? []
    }

    // MARK: - Phase

    func setStatus(_ status: JobStatus) async {
        do {
            try await supabase.from("jobs").update(["status": status.rawValue])
                .eq("id", value: job.id).execute()
            job.status = status
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Appointments & visits

    func addAppointment(mode: VisitMode, start: Date) async {
        await insertVisit(kind: .consult, mode: mode, start: start)
    }

    func addVisit(kind: VisitKind, start: Date) async {
        await insertVisit(kind: kind, mode: nil, start: start)
    }

    private func insertVisit(kind: VisitKind, mode: VisitMode?, start: Date) async {
        struct NewVisit: Encodable {
            let org_id: UUID; let job_id: UUID; let kind: VisitKind
            let mode: VisitMode?; let status: String; let scheduled_start: Date
        }
        do {
            let inserted: [Visit] = try await supabase.from("visits")
                .insert(NewVisit(org_id: job.org_id, job_id: job.id, kind: kind,
                                 mode: mode, status: "scheduled", scheduled_start: start))
                .select().execute().value
            if let new = inserted.first { visits.append(new) }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Quote accept / decline

    func declineQuote(_ quote: Quote) async {
        do {
            try await supabase.from("quotes")
                .update(["status": "declined"]).eq("id", value: quote.id).execute()
            await setStatus(.declined)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    // Accept a quote: mark approved, link it to this job, create an invoice that
    // copies the quote's line items (with deposit), and advance the job.
    func acceptQuote(_ quote: Quote, depositAmount: Double) async {
        do {
            try await supabase.from("quotes")
                .update(QuoteApproval(status: "approved", job_id: job.id,
                                      deposit_required: depositAmount > 0,
                                      deposit_amount: depositAmount))
                .eq("id", value: quote.id).execute()

            let lines: [LineItem] = (try? await supabase.from("quote_line_items")
                .select().eq("quote_id", value: quote.id).order("sort").execute().value) ?? []

            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            let number = "INV-\(Int(Date().timeIntervalSince1970))"
            let createdInvoice: [InsertedID] = try await supabase.from("invoices")
                .insert(NewInvoice(
                    org_id: job.org_id, client_id: quote.client_id, job_id: job.id,
                    quote_id: quote.id, number: number, status: "sent",
                    issued_at: df.string(from: Date()),
                    subtotal: quote.subtotal, tax: quote.tax, total: quote.total,
                    deposit_amount: depositAmount))
                .select("id").execute().value

            if let invID = createdInvoice.first?.id, !lines.isEmpty {
                let items = lines.enumerated().map { idx, l in
                    NewInvoiceItem(invoice_id: invID, description: l.description,
                                   quantity: l.quantity, unit_price: l.unit_price,
                                   taxable: l.taxable, sort: idx)
                }
                try await supabase.from("invoice_line_items").insert(items).execute()
            }

            await setStatus(.approved)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Payments (deposit + balance)

    func recordPayment(amount: Double, method: String) async {
        guard let inv = invoice else { return }
        struct NewPayment: Encodable {
            let org_id: UUID; let invoice_id: UUID; let amount: Double; let method: String
        }
        do {
            try await supabase.from("payments")
                .insert(NewPayment(org_id: job.org_id, invoice_id: inv.id,
                                   amount: amount, method: method))
                .execute()
            let newPaid = inv.amount_paid + amount
            let status = newPaid >= inv.total ? "paid" : "partial"
            try await supabase.from("invoices")
                .update(InvoicePaymentUpdate(amount_paid: newPaid, status: status))
                .eq("id", value: inv.id).execute()
            await load()
        } catch { errorMessage = error.localizedDescription }
    }
}

// Encodable payloads (mixed value types, so dedicated structs rather than dicts).
private struct QuoteApproval: Encodable {
    let status: String; let job_id: UUID
    let deposit_required: Bool; let deposit_amount: Double
}
private struct NewInvoice: Encodable {
    let org_id: UUID; let client_id: UUID; let job_id: UUID; let quote_id: UUID
    let number: String; let status: String; let issued_at: String
    let subtotal: Double; let tax: Double; let total: Double; let deposit_amount: Double
}
private struct NewInvoiceItem: Encodable {
    let invoice_id: UUID; let description: String
    let quantity: Double; let unit_price: Double; let taxable: Bool; let sort: Int
}
private struct InvoicePaymentUpdate: Encodable {
    let amount_paid: Double; let status: String
}

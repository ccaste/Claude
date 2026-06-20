import SwiftUI

struct JobDetailView: View {
    @StateObject private var vm: JobDetailViewModel

    @State private var clientName = ""
    @State private var property: Property?

    // Sheets / prompts
    @State private var showAppointment = false
    @State private var showVisit = false
    @State private var pendingQuote: Quote?
    @State private var depositText = ""
    @State private var showPayment = false
    @State private var paymentText = ""

    init(job: Job) { _vm = StateObject(wrappedValue: JobDetailViewModel(job: job)) }

    var body: some View {
        List {
            phaseSection
            appointmentsSection
            quotesSection
            if vm.job.status != .lead && vm.job.status != .quoted && vm.job.status != .declined {
                visitsSection
            }
            if let invoice = vm.invoice { invoiceSection(invoice) }
        }
        .navigationTitle(vm.job.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAppointment) {
            ScheduleVisitSheet(title: "New Appointment", isAppointment: true) { kind, mode, date in
                Task { await vm.addAppointment(mode: mode ?? .in_person, start: date) }
            }
        }
        .sheet(isPresented: $showVisit) {
            ScheduleVisitSheet(title: "Schedule Visit", isAppointment: false) { kind, _, date in
                Task { await vm.addVisit(kind: kind, start: date) }
            }
        }
        .alert("Deposit required?", isPresented: depositAlertBinding) {
            TextField("Deposit amount (0 for none)", text: $depositText)
                .keyboardType(.decimalPad)
            Button("Accept quote") {
                if let q = pendingQuote {
                    Task { await vm.acceptQuote(q, depositAmount: Double(depositText) ?? 0) }
                }
                pendingQuote = nil; depositText = ""
            }
            Button("Cancel", role: .cancel) { pendingQuote = nil; depositText = "" }
        } message: {
            Text("Accepting creates an invoice and moves this job to Approved.")
        }
        .alert("Record payment", isPresented: $showPayment) {
            TextField("Amount", text: $paymentText).keyboardType(.decimalPad)
            Button("Record") {
                Task { await vm.recordPayment(amount: Double(paymentText) ?? 0, method: "card") }
                paymentText = ""
            }
            Button("Cancel", role: .cancel) { paymentText = "" }
        }
        .task {
            await vm.load()
            await loadHeader()
        }
    }

    // MARK: - Sections

    private var phaseSection: some View {
        Section("Phase") {
            VStack(alignment: .leading, spacing: 8) {
                Text(vm.job.status.label).font(.title3.bold()).foregroundStyle(.green)
                Text("\(vm.job.service_type.label)\(vm.job.season_year.map { " · \(String($0)) season" } ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
                if !clientName.isEmpty { Text(clientName).font(.subheadline) }
                if let p = property { Text(p.oneLineAddress).font(.caption).foregroundStyle(.secondary) }
            }
            if let next = vm.job.status.next {
                Button {
                    Task { await vm.setStatus(next) }
                } label: {
                    Label("Advance to \(next.label)", systemImage: "arrow.right.circle")
                }
            }
            Menu {
                ForEach(JobStatus.pipeline + [.declined, .cancelled, .on_hold], id: \.self) { s in
                    Button(s.label) { Task { await vm.setStatus(s) } }
                }
            } label: {
                Label("Set phase…", systemImage: "slider.horizontal.3")
            }
        }
    }

    private var appointmentsSection: some View {
        Section("Appointments") {
            ForEach(vm.appointments) { appt in
                HStack {
                    Image(systemName: appt.mode == .virtual ? "video" : "person.fill")
                    VStack(alignment: .leading) {
                        Text(appt.mode?.label ?? "Appointment").font(.headline)
                        if let s = appt.scheduled_start {
                            Text(s, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button { showAppointment = true } label: {
                Label("Add appointment", systemImage: "calendar.badge.plus")
            }
        }
    }

    private var quotesSection: some View {
        Section("Quotes") {
            if vm.quotes.isEmpty {
                Text("No quote yet. Build the design on the property, then Generate Quote.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(vm.quotes) { quote in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(quote.number).font(.headline)
                        Spacer()
                        Text(quote.total.usd).font(.headline)
                    }
                    Text(quote.status.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    if quote.status == .draft || quote.status == .sent {
                        HStack {
                            Button("Accept") { pendingQuote = quote }
                                .buttonStyle(.borderedProminent).controlSize(.small)
                            Button("Decline", role: .destructive) {
                                Task { await vm.declineQuote(quote) }
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var visitsSection: some View {
        Section("Visits") {
            ForEach(vm.workVisits) { visit in
                HStack {
                    VStack(alignment: .leading) {
                        Text(visit.kind.label).font(.headline)
                        if let s = visit.scheduled_start {
                            Text(s, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(visit.status.label).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button { showVisit = true } label: {
                Label("Schedule visit", systemImage: "plus")
            }
        }
    }

    private func invoiceSection(_ invoice: Invoice) -> some View {
        Section("Invoice \(invoice.number)") {
            LabeledContent("Total", value: invoice.total.usd)
            if let dep = invoice.deposit_amount, dep > 0 {
                LabeledContent("Deposit", value: dep.usd)
            }
            LabeledContent("Paid", value: invoice.amount_paid.usd)
            LabeledContent("Balance") {
                Text(invoice.balance.usd).bold().foregroundStyle(invoice.balance > 0 ? .red : .green)
            }
            Button { showPayment = true } label: {
                Label("Record payment", systemImage: "dollarsign.circle")
            }
        }
    }

    // MARK: - Helpers

    private var depositAlertBinding: Binding<Bool> {
        Binding(get: { pendingQuote != nil }, set: { if !$0 { pendingQuote = nil } })
    }

    private func loadHeader() async {
        if let c: [Client] = try? await supabase.from("clients").select()
            .eq("id", value: vm.job.client_id).limit(1).execute().value {
            clientName = c.first?.name ?? ""
        }
        if let pid = vm.job.property_id,
           let p: [Property] = try? await supabase.from("properties").select()
            .eq("id", value: pid).limit(1).execute().value {
            property = p.first
        }
    }
}

// Reusable sheet for adding an appointment or a work visit.
struct ScheduleVisitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let isAppointment: Bool
    var onSave: (VisitKind, VisitMode?, Date) -> Void

    @State private var kind: VisitKind = .install
    @State private var mode: VisitMode = .in_person
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                if isAppointment {
                    Picker("Type", selection: $mode) {
                        ForEach(VisitMode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                } else {
                    Picker("Type", selection: $kind) {
                        ForEach(VisitKind.workKinds, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                DatePicker("When", selection: $date)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(isAppointment ? .consult : kind, isAppointment ? mode : nil, date)
                        dismiss()
                    }
                }
            }
        }
    }
}

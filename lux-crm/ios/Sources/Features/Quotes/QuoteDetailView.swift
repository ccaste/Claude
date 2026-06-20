import SwiftUI

struct QuoteDetailView: View {
    @StateObject private var vm: QuoteDetailViewModel
    var onDone: (() -> Void)?

    @State private var showDeposit = false
    @State private var showSendOptions = false
    @State private var showMail = false
    @State private var showText = false
    @State private var sendFallback = false

    init(quote: Quote, onDone: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: QuoteDetailViewModel(quote: quote))
        self.onDone = onDone
    }

    private var isOpen: Bool {
        vm.quote.status == .draft || vm.quote.status == .sent || vm.quote.status == .changes_requested
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("QUOTE").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(vm.quote.number).font(.title2.bold())
                    Text(vm.quote.status.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                    if !vm.clientName.isEmpty { Text(vm.clientName).font(.subheadline) }
                    if isOpen {
                        Label("This is a quote — it becomes a job once accepted.",
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Items") {
                ForEach(vm.lineItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description).font(.subheadline)
                            Text([item.light_type?.label, item.color, item.spacing]
                                .compactMap { $0 }.filter { $0 != "None" }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.lineTotal.usd).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Totals") {
                LabeledContent("Total", value: vm.quote.total.usd).font(.headline)
                LabeledContent("Deposit") {
                    HStack {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text((vm.quote.deposit_amount ?? 0).usd)
                            if vm.quote.deposit_type == "percent", let p = vm.quote.deposit_percent, p > 0 {
                                Text("\(p.trimmed)% of total").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Button("Edit") { showDeposit = true }.font(.caption)
                    }
                }
            }

            if isOpen {
                Section {
                    Button {
                        showSendOptions = true
                    } label: { Label("Send to customer", systemImage: "paperplane") }

                    Button {
                        Task { await vm.accept() }
                    } label: { Label("Accept quote", systemImage: "checkmark.circle.fill") }
                        .disabled(vm.working)

                    Button { Task { await vm.requestChanges() } } label: {
                        Label("Customer requested changes", systemImage: "arrow.uturn.left")
                    }
                    Button(role: .destructive) { Task { await vm.decline() } } label: {
                        Label("Declined", systemImage: "xmark.circle")
                    }
                }
            } else if vm.quote.status == .approved {
                Section {
                    Label("Accepted — job & invoice created", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    if let job = vm.createdJob {
                        NavigationLink("Open the job", value: job)
                    }
                }
            }
        }
        .navigationTitle("Quote")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Job.self) { JobDetailView(job: $0) }
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onDone() } }
            }
        }
        .sheet(isPresented: $showDeposit) {
            DepositEditorView(total: vm.quote.total,
                              currentType: vm.quote.deposit_type ?? "amount",
                              currentAmount: vm.quote.deposit_amount ?? 0,
                              currentPercent: vm.quote.deposit_percent ?? 0) { type, value in
                Task { await vm.setDeposit(type: type, value: value) }
            }
        }
        .confirmationDialog("Send quote", isPresented: $showSendOptions, titleVisibility: .visible) {
            Button("Email") { if Composer.canEmail && vm.clientEmail != nil { showMail = true } else { sendFallback = true } }
            Button("Text message") { if Composer.canText && vm.clientPhone != nil { showText = true } else { sendFallback = true } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showMail) {
            MailComposeView(recipients: [vm.clientEmail ?? ""],
                            subject: "Your LUX Lighting quote \(vm.quote.number)",
                            body: vm.messageBody()) {
                showMail = false
                Task { await vm.markSent(channel: "email", body: vm.messageBody()) }
            }
        }
        .sheet(isPresented: $showText) {
            MessageComposeView(recipients: [vm.clientPhone ?? ""], body: vm.messageBody()) {
                showText = false
                Task { await vm.markSent(channel: "sms", body: vm.messageBody()) }
            }
        }
        .alert("Can't send from here", isPresented: $sendFallback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add the customer's email/phone, and use a real device with Mail or Messages set up.")
        }
        .task { await vm.load() }
    }
}

// Set the required deposit as a fixed dollar amount or a percent of the total.
struct DepositEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let total: Double
    @State private var mode: String
    @State private var amount: Double
    @State private var percent: Double
    var onSave: (String, Double) -> Void

    init(total: Double, currentType: String, currentAmount: Double, currentPercent: Double,
         onSave: @escaping (String, Double) -> Void) {
        self.total = total
        _mode = State(initialValue: currentType)
        _amount = State(initialValue: currentAmount)
        _percent = State(initialValue: currentPercent)
        self.onSave = onSave
    }

    private var resolved: Double { mode == "percent" ? (total * percent / 100) : amount }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Deposit", selection: $mode) {
                    Text("Fixed amount").tag("amount")
                    Text("Percent of total").tag("percent")
                }
                .pickerStyle(.segmented)

                if mode == "amount" {
                    HStack {
                        Text("Amount"); Spacer(); Text("$")
                        TextField("0.00", value: $amount, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                    }
                } else {
                    HStack {
                        Text("Percent"); Spacer()
                        TextField("0", value: $percent, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                        Text("%")
                    }
                }

                Section {
                    LabeledContent("Quote total", value: total.usd)
                    LabeledContent("Deposit due", value: resolved.usd).font(.headline)
                }
            }
            .navigationTitle("Required Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(mode, mode == "percent" ? percent : amount)
                        dismiss()
                    }
                }
            }
        }
    }
}

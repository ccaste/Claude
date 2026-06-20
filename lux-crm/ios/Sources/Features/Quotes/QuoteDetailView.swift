import SwiftUI

struct QuoteDetailView: View {
    @StateObject private var vm: QuoteDetailViewModel
    var onDone: (() -> Void)?

    @State private var showDeposit = false
    @State private var depositText = ""
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
                        Text((vm.quote.deposit_amount ?? 0).usd)
                        Button("Edit") {
                            depositText = String(vm.quote.deposit_amount ?? 0)
                            showDeposit = true
                        }.font(.caption)
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
        .alert("Required deposit", isPresented: $showDeposit) {
            TextField("Amount", text: $depositText).keyboardType(.decimalPad)
            Button("Save") { Task { await vm.setDeposit(Double(depositText) ?? 0) } }
            Button("Cancel", role: .cancel) {}
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

import SwiftUI

struct QuoteBuilderView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm: QuoteBuilderViewModel
    var onFinish: () -> Void

    @State private var showPalette = false
    @State private var editingItem: QuoteItemDraft?

    init(property: Property, job: Job?, onFinish: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: QuoteBuilderViewModel(property: property, job: job))
        self.onFinish = onFinish
    }

    var body: some View {
        List {
            Section {
                if vm.items.isEmpty {
                    ContentUnavailableView("Build the quote",
                        systemImage: "plus.rectangle.on.rectangle",
                        description: Text("Tap “Add item” and pick what you're installing."))
                }
                ForEach(vm.items) { item in
                    Button { editingItem = item } label: { itemRow(item) }
                        .buttonStyle(.plain)
                }
                .onDelete { vm.remove(at: $0) }

                Button { showPalette = true } label: {
                    Label("Add item", systemImage: "plus.circle.fill")
                }
            } header: {
                Text(vm.property.label)
            }

            if !vm.items.isEmpty {
                Section {
                    HStack {
                        Text("Quote total").font(.headline)
                        Spacer()
                        Text(vm.total.usd).font(.title3.bold())
                    }
                }
            }
        }
        .navigationTitle("New Quote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        guard let orgID = auth.profile?.org_id else { return }
                        await vm.saveQuote(orgID: orgID)
                        if vm.savedQuoteNumber != nil { onFinish() }
                    }
                }
                .disabled(vm.items.isEmpty || vm.saving)
            }
        }
        .sheet(isPresented: $showPalette) {
            ItemPaletteView { type in vm.addItem(type) }
        }
        .sheet(item: $editingItem) { item in
            ItemEditorView(item: item, lookupDefault: { vm.defaultFor($0, $1) }) { vm.replace($0) }
        }
        .task {
            if let orgID = auth.profile?.org_id { await vm.loadDefaults(orgID: orgID) }
        }
    }

    private func itemRow(_ item: QuoteItemDraft) -> some View {
        HStack {
            Image(systemName: item.itemType.icon).foregroundStyle(.green).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemType.label).font(.headline)
                Text(item.summary).font(.caption).foregroundStyle(.secondary)
                Text("\(item.quantity.trimmed) \(item.unit) × \(item.unitPrice.usd)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.lineTotal.usd).font(.subheadline.bold())
        }
    }
}

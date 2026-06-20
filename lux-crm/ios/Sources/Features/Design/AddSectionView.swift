import SwiftUI

// Add one section to a design: pick a product from the price book, then enter
// the measurement (feet / strands / 9ft sections / count) and where it goes.
struct AddSectionView: View {
    @Environment(\.dismiss) private var dismiss

    let design: Design
    var onAdd: (SectionDraft) -> Void

    @StateObject private var catalog = CatalogViewModel()
    @State private var draft = SectionDraft()
    @State private var selectedID: UUID?

    private var selected: CatalogItem? { catalog.items.first { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Where? (Front roofline, oaks by driveway…)", text: $draft.label)
                }

                Section("Product") {
                    if catalog.items.isEmpty {
                        Text("Add products to your Price Book first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Product", selection: $selectedID) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(catalog.items) { item in
                                Text("\(item.name) — \(item.unit_price.usd)/\(item.pricing_unit.abbrev)")
                                    .tag(UUID?.some(item.id))
                            }
                        }
                    }
                }

                if let item = selected {
                    Section(item.pricing_unit.label) {
                        HStack {
                            Text(item.pricing_unit.quantityPrompt)
                            Spacer()
                            TextField("0", value: $draft.quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                            Text(item.pricing_unit.abbrev).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Rate")
                            Spacer()
                            Text("$")
                            TextField("0.00", value: $draft.unitPrice, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                        }
                        LabeledContent("Line total", value: (draft.quantity * draft.unitPrice).usd)
                            .font(.headline)
                    }

                    Section("Optional") {
                        TextField("Power circuit (Front porch GFCI…)", text: $draft.powerCircuit)
                        TextField("Notes", text: $draft.notes, axis: .vertical)
                    }
                }
            }
            .navigationTitle("Add Section")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedID) { _, _ in
                // Default the rate from the chosen product (still editable).
                if let item = selected {
                    draft.catalog = item
                    draft.productName = item.name
                    draft.pricingUnit = item.pricing_unit
                    draft.unitPrice = item.unit_price
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd(draft); dismiss() }
                        .disabled(selected == nil
                                  || draft.label.trimmingCharacters(in: .whitespaces).isEmpty
                                  || draft.quantity <= 0)
                }
            }
            .task { if catalog.items.isEmpty { await catalog.load() } }
        }
    }
}

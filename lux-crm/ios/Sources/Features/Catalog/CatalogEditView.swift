import SwiftUI

struct CatalogEditView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var vm: CatalogViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = CatalogDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name (e.g. C9 Warm White)", text: $draft.name)
                    Picker("Category", selection: $draft.category) {
                        ForEach(ProductCategory.allCases, id: \.self) { c in
                            Text(c.label).tag(c.rawValue)
                        }
                    }
                }

                Section("Pricing") {
                    Picker("Priced", selection: $draft.pricingUnit) {
                        ForEach(PricingUnit.allCases, id: \.self) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    HStack {
                        Text("Rate")
                        Spacer()
                        Text("$")
                        TextField("0.00", value: $draft.unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("/ \(draft.pricingUnit.abbrev)").foregroundStyle(.secondary)
                    }
                }

                Section("Details (optional)") {
                    TextField("Bulb type (C9, mini…)", text: $draft.bulbType)
                    TextField("Color", text: $draft.color)
                    TextField("Size (e.g. 24in wreath)", text: $draft.size)
                    TextField("Spacing (e.g. 12in)", text: $draft.spacing)
                }
            }
            .navigationTitle("New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let orgID = auth.profile?.org_id else { return }
                        Task { await vm.create(draft, orgID: orgID); dismiss() }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

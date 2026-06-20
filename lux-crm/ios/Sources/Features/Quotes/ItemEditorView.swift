import SwiftUI

// Edit one quote line. Light type drives the unit and spacing options; changing
// it re-pulls the default price/spacing for that item + light combination.
struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: QuoteItemDraft
    var lookupDefault: (ItemType, LightType) -> ItemDefault?
    var onSave: (QuoteItemDraft) -> Void

    init(item: QuoteItemDraft,
         lookupDefault: @escaping (ItemType, LightType) -> ItemDefault?,
         onSave: @escaping (QuoteItemDraft) -> Void) {
        _item = State(initialValue: item)
        self.lookupDefault = lookupDefault
        self.onSave = onSave
    }

    private let colors = ["Warm White", "Cool White", "Red", "Green", "Blue", "Multi", "Red & White"]

    private var spacingBinding: Binding<String> {
        Binding(get: { item.spacing ?? "" }, set: { item.spacing = $0.isEmpty ? nil : $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Area (e.g. front of house, garage peak)", text: $item.area)
                }

                Section("Lights") {
                    Picker("Light type", selection: $item.lightType) {
                        ForEach(item.itemType.lightOptions, id: \.self) { Text($0.label).tag($0) }
                    }
                    Picker("Color", selection: $item.color) {
                        ForEach(colors, id: \.self) { Text($0).tag($0) }
                        if !colors.contains(item.color) { Text(item.color).tag(item.color) }
                    }
                    if !item.lightType.spacingOptions.isEmpty {
                        Picker("Spacing", selection: spacingBinding) {
                            ForEach(item.lightType.spacingOptions, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }

                Section("Measurement & price") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", value: $item.quantity, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                        Text(item.unit).foregroundStyle(.secondary).frame(minWidth: 60, alignment: .trailing)
                    }
                    HStack {
                        Text("Price")
                        Spacer()
                        Text("$")
                        TextField("0.00", value: $item.unitPrice, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                        Text("/ \(item.unit)").foregroundStyle(.secondary)
                    }
                    LabeledContent("Line total", value: item.lineTotal.usd).font(.headline)
                }
            }
            .navigationTitle(item.itemType.label)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: item.lightType) { _, newLight in
                // Unit + spacing + default price follow the light type.
                item.unit = item.itemType.unit(for: newLight)
                let opts = newLight.spacingOptions
                if let s = item.spacing, !opts.contains(s) { item.spacing = newLight.defaultSpacing }
                if item.spacing == nil { item.spacing = newLight.defaultSpacing }
                if let d = lookupDefault(item.itemType, newLight) {
                    item.unitPrice = d.default_unit_price
                    if let c = d.default_color { item.color = c }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(item); dismiss() }
                }
            }
        }
    }
}

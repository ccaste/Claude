import SwiftUI

// Edit one quote line: area, light type, color, measurement, price.
struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: QuoteItemDraft
    var onSave: (QuoteItemDraft) -> Void

    init(item: QuoteItemDraft, onSave: @escaping (QuoteItemDraft) -> Void) {
        _item = State(initialValue: item)
        self.onSave = onSave
    }

    private let colors = ["Warm White", "Cool White", "Red", "Green", "Blue", "Multi", "Red & White"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Area (e.g. front of house, garage peak)", text: $item.area)
                }

                Section("Lights") {
                    Picker("Light type", selection: $item.lightType) {
                        ForEach(LightType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Picker("Color", selection: $item.color) {
                        ForEach(colors, id: \.self) { Text($0).tag($0) }
                        if !colors.contains(item.color) { Text(item.color).tag(item.color) }
                    }
                }

                Section("Measurement & price") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", value: $item.quantity, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                        TextField("unit", text: $item.unit).frame(maxWidth: 70)
                            .multilineTextAlignment(.trailing).foregroundStyle(.secondary)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(item); dismiss() }
                }
            }
        }
    }
}

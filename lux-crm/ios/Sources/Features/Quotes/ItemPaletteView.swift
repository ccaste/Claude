import SwiftUI

// Grid of item types to drop onto a quote.
struct ItemPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (ItemType) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ItemType.allCases) { type in
                        Button {
                            onPick(type)
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon).font(.title)
                                Text(type.label)
                                    .font(.caption).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 88)
                            .padding(8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .tint(.green)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

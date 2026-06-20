import SwiftUI
import Supabase

@MainActor
final class ItemDefaultsViewModel: ObservableObject {
    @Published var rows: [ItemDefault] = []
    @Published var isLoading = false

    func load(orgID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        rows = await ItemDefaultsStore.loadAndSeed(orgID: orgID)
    }

    func save(_ row: ItemDefault) async {
        struct Update: Encodable {
            let default_color: String?; let default_spacing: String?; let default_unit_price: Double
        }
        do {
            try await supabase.from("item_defaults")
                .update(Update(default_color: row.default_color,
                               default_spacing: row.default_spacing,
                               default_unit_price: row.default_unit_price))
                .eq("id", value: row.id).execute()
            if let i = rows.firstIndex(where: { $0.id == row.id }) { rows[i] = row }
        } catch { }
    }
}

struct ItemDefaultsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = ItemDefaultsViewModel()
    @State private var editing: ItemDefault?

    private static let lightOrder: [LightType] = [.c9, .c7, .mini, .none]

    private var grouped: [(type: ItemType, rows: [ItemDefault])] {
        Dictionary(grouping: vm.rows, by: \.item_type)
            .map { (type: $0.key, rows: $0.value.sorted {
                (Self.lightOrder.firstIndex(of: $0.light_type ?? .none) ?? 9)
                < (Self.lightOrder.firstIndex(of: $1.light_type ?? .none) ?? 9)
            }) }
            .sorted { $0.type.sortOrder < $1.type.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.type) { group in
                    Section(group.type.label) {
                        ForEach(group.rows) { row in
                            Button { editing = row } label: { rowView(row) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Defaults")
            .overlay { if vm.isLoading { ProgressView() } }
            .sheet(item: $editing) { row in
                ItemDefaultEditor(row: row) { updated in Task { await vm.save(updated) } }
            }
            .task { if let orgID = auth.profile?.org_id { await vm.load(orgID: orgID) } }
        }
    }

    private func unit(for row: ItemDefault) -> String {
        row.light_type.map { row.item_type.unit(for: $0) } ?? row.default_unit
    }

    private func rowView(_ row: ItemDefault) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.light_type?.label ?? "—").font(.headline)
                Text([row.default_color, row.default_spacing].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(row.default_unit_price.usd)/\(unit(for: row))")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct ItemDefaultEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var row: ItemDefault
    var onSave: (ItemDefault) -> Void

    private let colors = ["Warm White", "Cool White", "Red", "Green", "Blue", "Multi", "Red & White"]

    private var light: LightType { row.light_type ?? .none }
    private var unit: String { row.item_type.unit(for: light) }

    private var colorBinding: Binding<String> {
        Binding(get: { row.default_color ?? ItemType.defaultColor }, set: { row.default_color = $0 })
    }
    private var spacingBinding: Binding<String> {
        Binding(get: { row.default_spacing ?? "" }, set: { row.default_spacing = $0.isEmpty ? nil : $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Light", value: light.label)
                    LabeledContent("Priced", value: "per \(unit)")
                }
                Picker("Color", selection: colorBinding) {
                    ForEach(colors, id: \.self) { Text($0).tag($0) }
                }
                if !light.spacingOptions.isEmpty {
                    Picker("Spacing", selection: spacingBinding) {
                        ForEach(light.spacingOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
                HStack {
                    Text("Default price"); Spacer(); Text("$")
                    TextField("0.00", value: $row.default_unit_price, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                    Text("/ \(unit)").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("\(row.label) · \(light.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(row); dismiss() }
                }
            }
        }
    }
}

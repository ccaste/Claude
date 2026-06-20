import SwiftUI
import Supabase

@MainActor
final class ItemDefaultsViewModel: ObservableObject {
    @Published var rows: [ItemDefault] = []
    @Published var isLoading = false

    func load(orgID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        var result: [ItemDefault] = (try? await supabase.from("item_defaults")
            .select().eq("org_id", value: orgID).order("sort").execute().value) ?? []
        if result.isEmpty { result = await seed(orgID: orgID) }
        rows = result.sorted { $0.sort < $1.sort }
    }

    private func seed(orgID: UUID) async -> [ItemDefault] {
        struct NewDefault: Encodable {
            let org_id: UUID; let item_type: ItemType; let label: String
            let default_light_type: LightType; let default_color: String
            let default_unit: String; let default_unit_price: Double; let sort: Int
        }
        let payload = ItemType.allCases.map {
            NewDefault(org_id: orgID, item_type: $0, label: $0.label,
                       default_light_type: $0.defaultLight, default_color: ItemType.defaultColor,
                       default_unit: $0.defaultUnit, default_unit_price: 0, sort: $0.sortOrder)
        }
        return (try? await supabase.from("item_defaults")
            .insert(payload).select().execute().value) ?? []
    }

    func save(_ row: ItemDefault) async {
        struct Update: Encodable {
            let default_light_type: LightType?; let default_color: String?
            let default_unit: String; let default_unit_price: Double
        }
        do {
            try await supabase.from("item_defaults")
                .update(Update(default_light_type: row.default_light_type,
                               default_color: row.default_color,
                               default_unit: row.default_unit,
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.rows) { row in
                        Button { editing = row } label: {
                            HStack {
                                Image(systemName: row.item_type.icon)
                                    .foregroundStyle(.green).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.label).font(.headline)
                                    Text([row.default_light_type?.label, row.default_color]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(row.default_unit_price.usd)/\(row.default_unit)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("These pre-fill each quote. You can still change any value per quote.")
                }
            }
            .navigationTitle("Defaults")
            .overlay { if vm.isLoading { ProgressView() } }
            .sheet(item: $editing) { row in
                ItemDefaultEditor(row: row) { updated in
                    Task { await vm.save(updated) }
                }
            }
            .task { if let orgID = auth.profile?.org_id { await vm.load(orgID: orgID) } }
        }
    }
}

private struct ItemDefaultEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var row: ItemDefault
    var onSave: (ItemDefault) -> Void

    private let colors = ["Warm White", "Cool White", "Red", "Green", "Blue", "Multi", "Red & White"]
    private var lightBinding: Binding<LightType> {
        Binding(get: { row.default_light_type ?? .none }, set: { row.default_light_type = $0 })
    }
    private var colorBinding: Binding<String> {
        Binding(get: { row.default_color ?? ItemType.defaultColor }, set: { row.default_color = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Light type", selection: lightBinding) {
                    ForEach(LightType.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Color", selection: colorBinding) {
                    ForEach(colors, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Text("Unit"); Spacer()
                    TextField("each", text: $row.default_unit)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                }
                HStack {
                    Text("Default price"); Spacer(); Text("$")
                    TextField("0.00", value: $row.default_unit_price, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                    Text("/ \(row.default_unit)").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(row.label)
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

import SwiftUI

// The price book. Each product knows how it's priced (per ft, strand, 9ft, unit).
struct CatalogListView: View {
    @StateObject private var vm = CatalogViewModel()
    @State private var showingAdd = false

    var grouped: [(category: String, items: [CatalogItem])] {
        Dictionary(grouping: vm.items, by: \.category)
            .map { (category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }

    var body: some View {
        NavigationStack {
            List {
                if vm.items.isEmpty && !vm.isLoading {
                    ContentUnavailableView("No products yet",
                        systemImage: "tag",
                        description: Text("Add the lights and décor you sell, with how each is priced."))
                }
                ForEach(grouped, id: \.category) { group in
                    Section(ProductCategory(rawValue: group.category)?.label ?? group.category.capitalized) {
                        ForEach(group.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.headline)
                                    Text([item.bulb_type, item.color, item.size].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(item.unit_price.usd).font(.headline)
                                    Text(item.pricing_unit.abbrev).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Price Book")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { CatalogEditView(vm: vm) }
            .overlay { if vm.isLoading { ProgressView() } }
            .refreshable { await vm.load() }
            .task { if vm.items.isEmpty { await vm.load() } }
        }
    }
}

import SwiftUI

// A property: its info, the quotes built for it, and what's in storage.
struct PropertyDetailView: View {
    let property: Property

    @State private var quotes: [Quote] = []
    @State private var storage: [Fixture] = []
    @State private var buildingQuote: QuoteStart?

    var body: some View {
        List {
            Section("Address") {
                if !property.oneLineAddress.isEmpty { Text(property.oneLineAddress) }
                if let s = property.stories { LabeledContent("Stories", value: "\(s)") }
            }
            if let access = property.access_notes, !access.isEmpty {
                Section("Access") { Text(access) }
            }
            if let power = property.power_notes, !power.isEmpty {
                Section("Power") { Text(power) }
            }

            Section("Quotes") {
                if quotes.isEmpty { Text("No quotes yet.").foregroundStyle(.secondary) }
                ForEach(quotes) { q in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(q.number).font(.headline)
                            Text(q.status.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(q.total.usd).font(.headline)
                    }
                }
                Button { buildingQuote = QuoteStart(property: property) } label: {
                    Label("Build quote", systemImage: "plus.rectangle.on.rectangle")
                }
            }

            Section("In Storage") {
                if storage.isEmpty {
                    Text("Nothing stored yet. Items appear here once a quote is accepted.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(storage) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description ?? item.category).font(.subheadline)
                            Text([item.light_type?.label, item.color].compactMap { $0 }
                                .filter { $0 != "None" }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.status?.label ?? "In Storage").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(property.label)
        .navigationDestination(item: $buildingQuote) { q in
            QuoteBuilderView(property: q.property, job: nil) {
                buildingQuote = nil
                Task { await load() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        quotes = (try? await supabase.from("quotes").select()
            .eq("property_id", value: property.id)
            .order("created_at", ascending: false).execute().value) ?? []
        storage = (try? await supabase.from("fixtures").select()
            .eq("property_id", value: property.id).execute().value) ?? []
    }
}

struct QuoteStart: Hashable, Identifiable {
    let property: Property
    var id: UUID { property.id }
}

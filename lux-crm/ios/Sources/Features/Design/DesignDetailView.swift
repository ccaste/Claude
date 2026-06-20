import SwiftUI

// Build out a property's lighting design section by section, with a live total,
// then generate a quote.
struct DesignDetailView: View {
    @EnvironmentObject var auth: AuthViewModel
    let design: Design
    let property: Property

    @StateObject private var vm = DesignViewModel()
    @State private var showingAdd = false
    @State private var showQuoteAlert = false

    var body: some View {
        List {
            Section {
                ForEach(vm.sections) { section in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(section.label).font(.headline)
                            Spacer()
                            Text(section.lineTotal.usd).font(.headline)
                        }
                        Text(section.product_name).font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text("\(section.quantity.trimmed) \(section.pricing_unit.abbrev) × \(section.unit_price.usd)")
                            if let c = section.power_circuit, !c.isEmpty {
                                Text("· ⚡︎ \(c)")
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { idx in
                    Task { for i in idx { await vm.delete(vm.sections[i]) } }
                }

                Button {
                    showingAdd = true
                } label: {
                    Label("Add section", systemImage: "plus")
                }
            } header: {
                Text("Sections")
            } footer: {
                if vm.sections.isEmpty {
                    Text("Add roofline runs, tree wraps, wreaths, garland and more from your price book.")
                }
            }

            if !vm.sections.isEmpty {
                Section {
                    HStack {
                        Text("Estimate total").font(.headline)
                        Spacer()
                        Text(vm.total.usd).font(.title3.bold())
                    }
                    Button {
                        Task {
                            guard let orgID = auth.profile?.org_id else { return }
                            await vm.generateQuote(design: design, property: property, orgID: orgID)
                            if vm.lastQuoteNumber != nil { showQuoteAlert = true }
                        }
                    } label: {
                        Label("Generate quote", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("\(String(design.season_year)) Design")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) {
            AddSectionView(design: design) { draft in
                Task {
                    guard let orgID = auth.profile?.org_id else { return }
                    await vm.addSection(draft, design: design, orgID: orgID)
                }
            }
        }
        .alert("Quote created", isPresented: $showQuoteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Quote \(vm.lastQuoteNumber ?? "") for \(vm.total.usd) was created as a draft.")
        }
        .task { await vm.load(designID: design.id) }
    }
}

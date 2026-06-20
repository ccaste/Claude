import SwiftUI

// A property: its info, install notes, and the per-season lighting designs.
struct PropertyDetailView: View {
    @EnvironmentObject var auth: AuthViewModel
    let property: Property

    @State private var designs: [Design] = []
    @State private var isLoading = false

    var body: some View {
        List {
            Section("Address") {
                if !property.oneLineAddress.isEmpty {
                    Text(property.oneLineAddress)
                }
                if let s = property.stories { LabeledContent("Stories", value: "\(s)") }
            }

            if let access = property.access_notes, !access.isEmpty {
                Section("Access") { Text(access) }
            }
            if let power = property.power_notes, !power.isEmpty {
                Section("Power") { Text(power) }
            }

            Section("Lighting Designs") {
                if designs.isEmpty && !isLoading {
                    Text("No design yet. Create one for this season.")
                        .foregroundStyle(.secondary)
                }
                ForEach(designs) { design in
                    NavigationLink(value: design) {
                        HStack {
                            Text("\(String(design.season_year)) Season").font(.headline)
                            Spacer()
                            Text(design.status.label)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    Task { await createDesign() }
                } label: {
                    Label("New design for \(String(SeasonYear.current))", systemImage: "plus")
                }
            }
        }
        .navigationTitle(property.label)
        .navigationDestination(for: Design.self) { design in
            DesignDetailView(design: design, property: property)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        designs = (try? await supabase
            .from("designs").select()
            .eq("property_id", value: property.id)
            .order("season_year", ascending: false)
            .execute().value) ?? []
    }

    private func createDesign() async {
        guard let orgID = auth.profile?.org_id else { return }
        // Don't duplicate a design for the same season.
        if let existing = designs.first(where: { $0.season_year == SeasonYear.current }) {
            _ = existing
            return
        }
        struct NewDesign: Encodable {
            let org_id: UUID
            let property_id: UUID
            let season_year: Int
        }
        do {
            let inserted: [Design] = try await supabase
                .from("designs")
                .insert(NewDesign(org_id: orgID, property_id: property.id, season_year: SeasonYear.current))
                .select()
                .execute()
                .value
            if let new = inserted.first { designs.insert(new, at: 0) }
        } catch { }
    }
}

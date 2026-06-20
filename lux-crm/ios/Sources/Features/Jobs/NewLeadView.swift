import SwiftUI

// Step 1 of the lifecycle: capture interest as a lead with a property attached.
struct NewLeadView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    var onCreated: (Job) -> Void

    @State private var clients: [Client] = []
    @State private var properties: [Property] = []
    @State private var clientID: UUID?
    @State private var propertyID: UUID?
    @State private var serviceType: ServiceType = .christmas_lighting
    @State private var title = "Christmas \(String(SeasonYear.current))"
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    Picker("Client", selection: $clientID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(clients) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    if clientID != nil {
                        Picker("Property", selection: $propertyID) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(properties) { Text($0.label).tag(UUID?.some($0.id)) }
                        }
                        if properties.isEmpty {
                            Text("No properties for this client. Add one from the Clients tab first.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Job") {
                    TextField("Title", text: $title)
                    Picker("Service", selection: $serviceType) {
                        ForEach(ServiceType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
            }
            .navigationTitle("New Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(clientID == nil || propertyID == nil || saving)
                }
            }
            .task { await loadClients() }
            .onChange(of: clientID) { _, _ in Task { await loadProperties() } }
        }
    }

    private func loadClients() async {
        clients = (try? await supabase.from("clients").select()
            .eq("archived", value: false).order("name").execute().value) ?? []
    }

    private func loadProperties() async {
        propertyID = nil
        guard let clientID else { properties = []; return }
        properties = (try? await supabase.from("properties").select()
            .eq("client_id", value: clientID).order("label").execute().value) ?? []
    }

    private func create() async {
        guard let orgID = auth.profile?.org_id, let clientID, let propertyID else { return }
        saving = true
        defer { saving = false }
        struct NewJob: Encodable {
            let org_id: UUID; let client_id: UUID; let property_id: UUID
            let title: String; let service_type: ServiceType
            let status: String; let season_year: Int
        }
        do {
            let inserted: [Job] = try await supabase.from("jobs")
                .insert(NewJob(org_id: orgID, client_id: clientID, property_id: propertyID,
                               title: title, service_type: serviceType,
                               status: "lead", season_year: SeasonYear.current))
                .select().execute().value
            if let new = inserted.first { onCreated(new) }
            dismiss()
        } catch { dismiss() }
    }
}

import SwiftUI

// Where a new request begins: pick or create the customer + property, then jump
// straight into building the quote.
struct NewRequestView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    var onFinish: () -> Void

    enum Mode: String, CaseIterable { case existing = "Existing", new = "New" }
    @State private var mode: Mode = .existing

    // Existing customer
    @State private var clients: [Client] = []
    @State private var clientID: UUID?
    @State private var properties: [Property] = []
    @State private var propertyID: UUID?

    // New customer
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var label = "Home"
    @State private var line1 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""

    @State private var started: StartedRequest?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Customer", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .existing {
                    existingSection
                } else {
                    newSection
                }
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Quote") { Task { await start() } }
                        .disabled(!canStart || working)
                }
            }
            .navigationDestination(item: $started) { ctx in
                QuoteBuilderView(property: ctx.property, job: ctx.job) {
                    onFinish(); dismiss()
                }
            }
            .task { await loadClients() }
            .onChange(of: clientID) { _, _ in Task { await loadProperties() } }
        }
    }

    @ViewBuilder private var existingSection: some View {
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
                    Text("No properties yet — switch to New, or add one from Clients.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var newSection: some View {
        Section("Customer") {
            TextField("Name", text: $name)
            TextField("Phone", text: $phone).keyboardType(.phonePad)
            TextField("Email", text: $email).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
        }
        Section("Property address") {
            TextField("Label (Home, Lake house…)", text: $label)
            TextField("Street address", text: $line1)
            TextField("City", text: $city)
            HStack {
                TextField("State", text: $state)
                TextField("ZIP", text: $zip).keyboardType(.numbersAndPunctuation)
            }
        }
    }

    private var canStart: Bool {
        if mode == .existing { return clientID != nil && propertyID != nil }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && !line1.isEmpty
    }

    // MARK: - Data

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

    private func start() async {
        guard let orgID = auth.profile?.org_id else { return }
        working = true
        defer { working = false }
        do {
            let property: Property
            if mode == .existing {
                guard let pid = propertyID,
                      let p = properties.first(where: { $0.id == pid }) else { return }
                property = p
            } else {
                let client = try await insertClient(orgID: orgID)
                property = try await insertProperty(orgID: orgID, clientID: client.id)
            }
            let job = try await insertLead(orgID: orgID, property: property)
            started = StartedRequest(job: job, property: property)
        } catch {
            // Surface nothing fancy; leave the form so they can retry.
        }
    }

    private func insertClient(orgID: UUID) async throws -> Client {
        struct NewClient: Encodable {
            let org_id: UUID; let name: String; let phone: String?; let email: String?
        }
        let rows: [Client] = try await supabase.from("clients")
            .insert(NewClient(org_id: orgID, name: name, phone: phone.nilIfEmpty, email: email.nilIfEmpty))
            .select().execute().value
        return rows.first!
    }

    private func insertProperty(orgID: UUID, clientID: UUID) async throws -> Property {
        struct NewProperty: Encodable {
            let org_id: UUID; let client_id: UUID; let label: String
            let line1: String?; let city: String?; let state: String?; let zip: String?
        }
        let rows: [Property] = try await supabase.from("properties")
            .insert(NewProperty(org_id: orgID, client_id: clientID, label: label,
                                line1: line1.nilIfEmpty, city: city.nilIfEmpty,
                                state: state.nilIfEmpty, zip: zip.nilIfEmpty))
            .select().execute().value
        return rows.first!
    }

    private func insertLead(orgID: UUID, property: Property) async throws -> Job {
        struct NewJob: Encodable {
            let org_id: UUID; let client_id: UUID; let property_id: UUID
            let title: String; let service_type: ServiceType; let status: String; let season_year: Int
        }
        let rows: [Job] = try await supabase.from("jobs")
            .insert(NewJob(org_id: orgID, client_id: property.client_id, property_id: property.id,
                           title: "Christmas \(String(SeasonYear.current))",
                           service_type: .christmas_lighting, status: "lead",
                           season_year: SeasonYear.current))
            .select().execute().value
        return rows.first!
    }
}

struct StartedRequest: Hashable {
    let job: Job
    let property: Property
}

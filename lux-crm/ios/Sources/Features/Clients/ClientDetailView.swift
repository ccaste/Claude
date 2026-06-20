import SwiftUI

struct ClientDetailView: View {
    let client: Client
    @State private var properties: [Property] = []
    @State private var jobs: [Job] = []

    var body: some View {
        List {
            Section("Contact") {
                if let company = client.company, !company.isEmpty { row("Company", company) }
                if let phone = client.phone, !phone.isEmpty {
                    Link(destination: URL(string: "tel:\(phone.filter(\.isNumber))")!) {
                        row("Phone", phone)
                    }
                }
                if let email = client.email, !email.isEmpty {
                    Link(destination: URL(string: "mailto:\(email)")!) { row("Email", email) }
                }
                if let source = client.source, !source.isEmpty { row("Source", source) }
            }

            Section("Properties") {
                if properties.isEmpty {
                    Text("No properties yet").foregroundStyle(.secondary)
                }
                ForEach(properties) { property in
                    VStack(alignment: .leading) {
                        Text(property.label).font(.headline)
                        Text(property.oneLineAddress).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Jobs") {
                if jobs.isEmpty {
                    Text("No jobs yet").foregroundStyle(.secondary)
                }
                ForEach(jobs) { job in
                    VStack(alignment: .leading) {
                        Text(job.title).font(.headline)
                        Text("\(job.service_type.label) · \(job.status.label)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let notes = client.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
        }
        .navigationTitle(client.name)
        .task { await loadRelated() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func loadRelated() async {
        async let props: [Property] = (try? await supabase
            .from("properties").select().eq("client_id", value: client.id)
            .execute().value) ?? []
        async let clientJobs: [Job] = (try? await supabase
            .from("jobs").select().eq("client_id", value: client.id)
            .order("created_at", ascending: false)
            .execute().value) ?? []
        properties = await props
        jobs = await clientJobs
    }
}

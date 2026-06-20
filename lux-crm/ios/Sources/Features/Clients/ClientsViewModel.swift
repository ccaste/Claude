import Foundation
import Supabase

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            clients = try await supabase
                .from("clients")
                .select()
                .eq("archived", value: false)
                .order("name")
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Insert a new client. org_id is required by RLS — we read it from the
    // signed-in user's profile.
    func create(name: String, company: String?, email: String?, phone: String?, orgID: UUID) async {
        struct NewClient: Encodable {
            let org_id: UUID
            let name: String
            let company: String?
            let email: String?
            let phone: String?
        }
        do {
            let inserted: [Client] = try await supabase
                .from("clients")
                .insert(NewClient(org_id: orgID, name: name, company: company, email: email, phone: phone))
                .select()
                .execute()
                .value
            if let new = inserted.first { clients.append(new); clients.sort { $0.name < $1.name } }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

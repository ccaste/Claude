import SwiftUI

struct ClientsListView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = ClientsViewModel()
    @State private var search = ""
    @State private var showingAdd = false

    var filtered: [Client] {
        guard !search.isEmpty else { return vm.clients }
        return vm.clients.filter {
            $0.name.localizedCaseInsensitiveContains(search)
            || ($0.company?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if vm.clients.isEmpty && !vm.isLoading {
                    ContentUnavailableView("No clients yet",
                        systemImage: "person.2",
                        description: Text("Tap + to add your first customer."))
                }
                ForEach(filtered) { client in
                    NavigationLink(value: client) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.name).font(.headline)
                            if let company = client.company, !company.isEmpty {
                                Text(company).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let phone = client.phone, !phone.isEmpty {
                                Text(phone).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Clients")
            .searchable(text: $search, prompt: "Search clients")
            .navigationDestination(for: Client.self) { ClientDetailView(client: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") { Task { await auth.signOut() } }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ClientEditView(vm: vm)
            }
            .overlay { if vm.isLoading { ProgressView() } }
            .refreshable { await vm.load() }
            .task { if vm.clients.isEmpty { await vm.load() } }
        }
    }
}

import SwiftUI

// Add-a-client sheet. (Editing existing clients comes in Phase 2.)
struct ClientEditView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var vm: ClientsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var company = ""
    @State private var email = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name)
                    TextField("Company (optional)", text: $company)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let orgID = auth.profile?.org_id else { return }
                        Task {
                            await vm.create(
                                name: name,
                                company: company.isEmpty ? nil : company,
                                email: email.isEmpty ? nil : email,
                                phone: phone.isEmpty ? nil : phone,
                                orgID: orgID
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

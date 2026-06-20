import SwiftUI

// Add-a-property sheet. Called from a client's detail screen.
struct PropertyEditView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let clientID: UUID
    var onSaved: (Property) -> Void

    @State private var label = "Home"
    @State private var line1 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var stories = ""
    @State private var accessNotes = ""
    @State private var powerNotes = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    TextField("Label (Home, Lake house…)", text: $label)
                    TextField("Street address", text: $line1)
                    TextField("City", text: $city)
                    HStack {
                        TextField("State", text: $state)
                        TextField("ZIP", text: $zip).keyboardType(.numbersAndPunctuation)
                    }
                    TextField("Stories (roofline height)", text: $stories)
                        .keyboardType(.numberPad)
                }
                Section("Install notes") {
                    TextField("Access (gate codes, dogs, parking)", text: $accessNotes, axis: .vertical)
                    TextField("Power (outdoor outlets, timers, breakers)", text: $powerNotes, axis: .vertical)
                }
            }
            .navigationTitle("New Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }

    private func save() async {
        guard let orgID = auth.profile?.org_id else { return }
        saving = true
        defer { saving = false }
        struct NewProperty: Encodable {
            let org_id: UUID
            let client_id: UUID
            let label: String
            let line1: String?
            let city: String?
            let state: String?
            let zip: String?
            let stories: Int?
            let access_notes: String?
            let power_notes: String?
        }
        do {
            let inserted: [Property] = try await supabase
                .from("properties")
                .insert(NewProperty(
                    org_id: orgID, client_id: clientID, label: label,
                    line1: line1.nilIfEmpty, city: city.nilIfEmpty,
                    state: state.nilIfEmpty, zip: zip.nilIfEmpty,
                    stories: Int(stories), access_notes: accessNotes.nilIfEmpty,
                    power_notes: powerNotes.nilIfEmpty))
                .select()
                .execute()
                .value
            if let new = inserted.first { onSaved(new) }
            dismiss()
        } catch {
            dismiss()
        }
    }
}

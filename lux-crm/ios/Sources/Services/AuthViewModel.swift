import Foundation
import Supabase

// Owns auth state for the app and exposes the signed-in user's profile.
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var profile: Profile?
    @Published var isLoading = true
    @Published var errorMessage: String?

    init() {
        Task { await bootstrap() }
    }

    // Restore an existing session on launch, if any.
    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await supabase.auth.session
            await loadProfile()
            isAuthenticated = profile != nil
        } catch {
            isAuthenticated = false
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.signIn(email: email, password: password)
            await loadProfile()
            isAuthenticated = profile != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        profile = nil
        isAuthenticated = false
    }

    private func loadProfile() async {
        do {
            let userID = try await supabase.auth.session.user.id
            let rows: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .limit(1)
                .execute()
                .value
            profile = rows.first
        } catch {
            profile = nil
        }
    }
}

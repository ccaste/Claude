import Foundation

// Supabase project credentials.
//
// These are the *anon* (public) key and project URL — safe to ship in a client
// app because Row-Level Security (see backend/0002_rls.sql) is what actually
// protects the data. Never put the service_role key in the app.
//
// Fill these in from your Supabase dashboard → Project Settings → API.
// For real builds, prefer injecting via an .xcconfig / build setting rather than
// hard-coding, but this is fine to get started.
enum SupabaseConfig {
    static let url = URL(string: "https://noeceqqsawykybfavygn.supabase.co")!
    static let anonKey = "YOUR-SUPABASE-ANON-KEY"  // Settings → API → Project API keys → anon public

    // Base URL for Edge Functions (the customer quote portal lives here).
    static let functionsBase = "https://noeceqqsawykybfavygn.functions.supabase.co"
}

extension Quote {
    // The link a customer opens to view and accept this quote.
    var portalURL: URL? {
        guard let token = public_token else { return nil }
        return URL(string: "\(SupabaseConfig.functionsBase)/quote?token=\(token.uuidString.lowercased())")
    }
}

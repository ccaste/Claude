import Foundation
import Supabase

// Single shared Supabase client for the whole app.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)

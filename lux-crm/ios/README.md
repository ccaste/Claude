# LUX CRM — iPhone app (SwiftUI)

Native iOS app. Requires a Mac with Xcode 15+.

## Build & run

1. Finish the [backend setup](../backend/README.md) and grab your Project URL +
   anon key.
2. Paste them into `Sources/Config/SupabaseConfig.swift`.
3. Generate the Xcode project (the `.xcodeproj` isn't checked in — it's generated
   from `project.yml` so it never drifts):

   ```sh
   brew install xcodegen        # once
   cd ios
   xcodegen                     # creates LUXCRM.xcodeproj
   open LUXCRM.xcodeproj
   ```

   Xcode will resolve the `supabase-swift` Swift Package on first open.
4. Pick an iPhone simulator (or your own device) and press **Run** (⌘R).
5. Sign in with the email/password you created in Authentication.

> To run on your physical iPhone you'll need to set a Development Team in
> Signing & Capabilities (your free Apple ID works for personal devices; the
> $99/yr Apple Developer Program is needed for TestFlight / App Store).

## Project layout

```
Sources/
  App/        LUXApp (entry), RootView (auth gate + tab bar)
  Config/     SupabaseConfig (URL + anon key)
  Models/     Codable types mirroring the Postgres tables
  Services/   Supabase client, AuthViewModel
  Features/
    Auth/       LoginView
    Dashboard/  Today view
    Schedule/   Day schedule of visits
    Clients/    List, detail, add + view model
    Jobs/       Jobs list
```

## Notes

- Models use `snake_case` names to decode straight from PostgREST JSON.
- All data access goes through the shared `supabase` client; RLS scopes results
  to the signed-in user's org automatically.
- This is the Phase 1 slice — creating jobs/visits, editing properties, photos,
  quotes/invoices, and payments come in later phases (see top-level README).

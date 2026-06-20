# LUX CRM — Backend (Supabase)

Postgres schema + row-level security for the CRM.

## One-time setup

1. Create a project at [supabase.com](https://supabase.com) (free tier is fine to start).
2. In the dashboard, open **SQL Editor** and run the migrations **in order**:
   - `supabase/migrations/0001_schema.sql`
   - `supabase/migrations/0002_rls.sql`
   - `supabase/migrations/0003_christmas.sql`  (Christmas design + price book + storage)
   - `supabase/migrations/0004_lifecycle.sql`  (lifecycle phases, appointments, deposits)
   - `supabase/migrations/0005_quote_items.sql` (rich quote items + item defaults)

   (Or use the Supabase CLI: `supabase db push`.)

3. Create your organization and your owner account. In the SQL Editor:

   ```sql
   -- a) create the org
   insert into organizations (name) values ('LUX Lighting Services')
   returning id;   -- copy this org id
   ```

   Then create your login under **Authentication → Users → Add user** (email +
   password). Copy that user's UUID, then link it to a profile:

   ```sql
   insert into profiles (id, org_id, full_name, role)
   values ('<auth-user-uuid>', '<org-id>', 'Carlos', 'owner');
   ```

4. Add crew the same way: create a user in Authentication, then insert a
   `profiles` row with the same `org_id` and `role = 'crew'`.

## Getting your app keys

**Project Settings → API**:
- **Project URL** and **anon public key** → paste into
  `ios/Sources/Config/SupabaseConfig.swift`.
- Never put the **service_role** key in the app.

## How permissions work

Every table carries an `org_id`, and RLS restricts every query to the signed-in
user's org (`auth_org_id()`). Owners/admins (`auth_is_admin()`) can manage the
team and org settings. This is what makes the multi-user/team model safe — even
though the app ships with the public anon key, users can only ever touch their
own org's rows.

## Later phases

- **Storage bucket** for property/install photos (Phase 2).
- **Edge Functions** for Stripe payments and Resend/Twilio messaging (Phase 3) —
  these hold the secret keys server-side, never in the app.

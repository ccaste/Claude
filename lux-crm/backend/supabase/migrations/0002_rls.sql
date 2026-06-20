-- Row-level security: every user only sees their own organization's data.
-- This is what makes the team multi-user model safe.

-- Helper: the org_id of the currently authenticated user.
create or replace function auth_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select org_id from profiles where id = auth.uid()
$$;

-- Helper: is the current user an owner/admin (can manage billing, team, deletes)?
create or replace function auth_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role in ('owner', 'admin')
  )
$$;

-- Enable RLS on every table.
alter table organizations     enable row level security;
alter table profiles          enable row level security;
alter table clients           enable row level security;
alter table properties        enable row level security;
alter table fixtures          enable row level security;
alter table jobs              enable row level security;
alter table visits            enable row level security;
alter table quotes            enable row level security;
alter table quote_line_items  enable row level security;
alter table invoices          enable row level security;
alter table invoice_line_items enable row level security;
alter table payments          enable row level security;
alter table time_entries      enable row level security;
alter table messages          enable row level security;

-- Organizations: members can read their own org.
create policy org_read on organizations
  for select using (id = auth_org_id());
create policy org_update on organizations
  for update using (id = auth_org_id() and auth_is_admin());

-- Profiles: read teammates in same org; users update their own row; admins manage.
create policy profile_read on profiles
  for select using (org_id = auth_org_id());
create policy profile_self_update on profiles
  for update using (id = auth.uid());
create policy profile_admin_all on profiles
  for all using (org_id = auth_org_id() and auth_is_admin())
  with check (org_id = auth_org_id());

-- Generic per-org tables: full CRUD scoped to the user's org.
-- (Tighten DELETE to admins later if you want crew to be read/write but not delete.)
create policy clients_rw on clients
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy properties_rw on properties
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy fixtures_rw on fixtures
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy jobs_rw on jobs
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy visits_rw on visits
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy quotes_rw on quotes
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy invoices_rw on invoices
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy payments_rw on payments
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy time_entries_rw on time_entries
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy messages_rw on messages
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());

-- Line items: scoped via their parent quote/invoice org.
create policy quote_items_rw on quote_line_items
  for all using (
    exists (select 1 from quotes q where q.id = quote_id and q.org_id = auth_org_id())
  ) with check (
    exists (select 1 from quotes q where q.id = quote_id and q.org_id = auth_org_id())
  );
create policy invoice_items_rw on invoice_line_items
  for all using (
    exists (select 1 from invoices i where i.id = invoice_id and i.org_id = auth_org_id())
  ) with check (
    exists (select 1 from invoices i where i.id = invoice_id and i.org_id = auth_org_id())
  );

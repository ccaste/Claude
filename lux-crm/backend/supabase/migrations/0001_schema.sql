-- LUX CRM — core schema
-- Field-service CRM for LUX Lighting Services (Christmas + landscape lighting).
-- Tailored for: multi-year property profiles, paired install/removal visits,
-- per-property fixture inventory, quotes, invoices, payments, time, messaging.

-- ─────────────────────────────────────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────────────────────────────────────
create type user_role       as enum ('owner', 'admin', 'crew');
create type service_type     as enum ('christmas_lighting', 'landscape_lighting', 'maintenance', 'repair', 'other');
create type job_status       as enum ('lead', 'quoted', 'approved', 'scheduled', 'in_progress', 'completed', 'on_hold', 'cancelled');
create type visit_kind       as enum ('consult', 'install', 'service', 'maintenance', 'removal');
create type visit_status     as enum ('unscheduled', 'scheduled', 'en_route', 'in_progress', 'completed', 'skipped');
create type quote_status     as enum ('draft', 'sent', 'approved', 'declined', 'expired');
create type invoice_status   as enum ('draft', 'sent', 'partial', 'paid', 'overdue', 'void');
create type payment_method   as enum ('card', 'cash', 'check', 'ach', 'other');
create type message_channel  as enum ('email', 'sms');
create type message_direction as enum ('outbound', 'inbound');

-- ─────────────────────────────────────────────────────────────────────────────
-- Organizations & team
-- ─────────────────────────────────────────────────────────────────────────────
create table organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  timezone    text not null default 'America/New_York',
  created_at  timestamptz not null default now()
);

-- One row per authenticated user, linked to Supabase auth.users.
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  org_id      uuid not null references organizations(id) on delete cascade,
  full_name   text not null default '',
  role        user_role not null default 'crew',
  phone       text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index on profiles (org_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Clients & properties
-- ─────────────────────────────────────────────────────────────────────────────
create table clients (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  name          text not null,
  company       text,
  email         text,
  phone         text,
  billing_line1 text,
  billing_line2 text,
  billing_city  text,
  billing_state text,
  billing_zip   text,
  source        text,                 -- how they found LUX (referral, web, etc.)
  notes         text,
  archived      boolean not null default false,
  created_at    timestamptz not null default now()
);
create index on clients (org_id);
create index on clients (org_id, name);

-- A client can have several serviceable properties. Christmas/landscape work is
-- property-centric, so most jobs hang off a property.
create table properties (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  client_id     uuid not null references clients(id) on delete cascade,
  label         text not null default 'Home',   -- e.g. "Main house", "Lake cabin"
  line1         text,
  line2         text,
  city          text,
  state         text,
  zip           text,
  latitude      double precision,
  longitude     double precision,
  stories       int,                  -- roofline height matters for Christmas installs
  access_notes  text,                 -- gate codes, dogs, parking
  power_notes   text,                 -- outdoor outlets, breaker locations, timers
  notes         text,
  created_at    timestamptz not null default now()
);
create index on properties (org_id);
create index on properties (client_id);

-- Per-property light/fixture inventory. For landscape: fixtures, transformers,
-- wattage. For Christmas: footage of C9, mini-trees, wreaths, what's in storage.
create table fixtures (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  property_id     uuid not null references properties(id) on delete cascade,
  category        text not null,      -- 'roofline_c9', 'path_light', 'transformer', 'wreath', ...
  description     text,
  quantity        numeric not null default 1,
  unit            text default 'each',-- 'each', 'ft', 'watt'
  wattage         numeric,            -- for landscape load / transformer sizing
  location        text,               -- 'front roofline', 'driveway bed', 'oak by mailbox'
  owned_by_client boolean not null default false, -- false = LUX-owned (rental program)
  in_storage      boolean not null default false, -- Christmas decor stored off-season
  installed_year  int,
  notes           text,
  created_at      timestamptz not null default now()
);
create index on fixtures (org_id);
create index on fixtures (property_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Jobs & visits
-- ─────────────────────────────────────────────────────────────────────────────
-- A job is a unit of work for a season. A Christmas job typically has two visits:
-- an install in Nov/Dec and a removal in Jan. Landscape jobs may be one install
-- plus recurring maintenance visits.
create table jobs (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  client_id     uuid not null references clients(id) on delete cascade,
  property_id   uuid references properties(id) on delete set null,
  title         text not null,
  service_type  service_type not null default 'christmas_lighting',
  status        job_status not null default 'lead',
  season_year   int,                  -- e.g. 2026 for the 2026 holiday season
  is_recurring  boolean not null default false, -- annual repeat customer
  description   text,
  created_at    timestamptz not null default now()
);
create index on jobs (org_id);
create index on jobs (org_id, status);
create index on jobs (client_id);
create index on jobs (property_id);

create table visits (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  job_id          uuid not null references jobs(id) on delete cascade,
  kind            visit_kind not null default 'install',
  status          visit_status not null default 'unscheduled',
  assigned_to     uuid references profiles(id) on delete set null,
  scheduled_start timestamptz,
  scheduled_end   timestamptz,
  completed_at    timestamptz,
  notes           text,
  created_at      timestamptz not null default now()
);
create index on visits (org_id);
create index on visits (job_id);
create index on visits (org_id, scheduled_start);
create index on visits (assigned_to);

-- ─────────────────────────────────────────────────────────────────────────────
-- Quotes & invoices
-- ─────────────────────────────────────────────────────────────────────────────
create table quotes (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references organizations(id) on delete cascade,
  client_id    uuid not null references clients(id) on delete cascade,
  property_id  uuid references properties(id) on delete set null,
  job_id       uuid references jobs(id) on delete set null,
  number       text not null,         -- human-facing, e.g. "Q-1042"
  status       quote_status not null default 'draft',
  issued_at    date,
  expires_at   date,
  tax_rate     numeric not null default 0,   -- percent, e.g. 7.0
  subtotal     numeric not null default 0,
  tax          numeric not null default 0,
  total        numeric not null default 0,
  notes        text,
  created_at   timestamptz not null default now(),
  unique (org_id, number)
);
create index on quotes (org_id);
create index on quotes (client_id);

create table quote_line_items (
  id          uuid primary key default gen_random_uuid(),
  quote_id    uuid not null references quotes(id) on delete cascade,
  description text not null,
  quantity    numeric not null default 1,
  unit_price  numeric not null default 0,
  taxable     boolean not null default true,
  sort        int not null default 0
);
create index on quote_line_items (quote_id);

create table invoices (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references organizations(id) on delete cascade,
  client_id    uuid not null references clients(id) on delete cascade,
  job_id       uuid references jobs(id) on delete set null,
  quote_id     uuid references quotes(id) on delete set null,
  number       text not null,
  status       invoice_status not null default 'draft',
  issued_at    date,
  due_at       date,
  tax_rate     numeric not null default 0,
  subtotal     numeric not null default 0,
  tax          numeric not null default 0,
  total        numeric not null default 0,
  amount_paid  numeric not null default 0,
  notes        text,
  created_at   timestamptz not null default now(),
  unique (org_id, number)
);
create index on invoices (org_id);
create index on invoices (org_id, status);
create index on invoices (client_id);

create table invoice_line_items (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references invoices(id) on delete cascade,
  description text not null,
  quantity    numeric not null default 1,
  unit_price  numeric not null default 0,
  taxable     boolean not null default true,
  sort        int not null default 0
);
create index on invoice_line_items (invoice_id);

create table payments (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references organizations(id) on delete cascade,
  invoice_id             uuid not null references invoices(id) on delete cascade,
  amount                 numeric not null,
  method                 payment_method not null default 'card',
  stripe_payment_intent  text,
  paid_at                timestamptz not null default now(),
  notes                  text
);
create index on payments (org_id);
create index on payments (invoice_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Time tracking & messaging log
-- ─────────────────────────────────────────────────────────────────────────────
create table time_entries (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  job_id      uuid references jobs(id) on delete set null,
  visit_id    uuid references visits(id) on delete set null,
  profile_id  uuid not null references profiles(id) on delete cascade,
  started_at  timestamptz not null,
  ended_at    timestamptz,
  notes       text,
  created_at  timestamptz not null default now()
);
create index on time_entries (org_id);
create index on time_entries (profile_id);
create index on time_entries (job_id);

-- Log of automated/manual client messages (reminders, quote sent, etc.).
create table messages (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  client_id   uuid references clients(id) on delete set null,
  channel     message_channel not null,
  direction   message_direction not null default 'outbound',
  subject     text,
  body        text not null,
  status      text not null default 'queued',  -- queued/sent/delivered/failed
  provider_id text,                            -- Twilio/Resend message id
  sent_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index on messages (org_id);
create index on messages (client_id);

-- Christmas lighting Phase 2: price book, per-property seasonal designs, design
-- sections (with mixed pricing units), power circuits, and customer-owned
-- material/storage tracking.

-- How a catalog product is priced. Maps to how LUX actually quotes:
--   linear_ft  → C9 roofline runs
--   strand     → mini-light strands (tree/bush wraps)
--   section_9ft→ garland (sold by the 9-foot section)
--   each       → wreaths (priced per size+count), sparklers, accents
create type pricing_unit    as enum ('linear_ft', 'strand', 'section_9ft', 'each');
create type design_status   as enum ('draft', 'quoted', 'active', 'archived');
create type material_status as enum ('in_storage', 'installed', 'returned_to_customer');

-- Price book: everything LUX sells & installs, each with its pricing unit + rate.
create table product_catalog (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references organizations(id) on delete cascade,
  name         text not null,        -- "C9 Warm White", "Mini Strand WW", "24in Wreath", "9ft Garland", "Sparkler"
  category     text not null default 'other', -- roofline, tree_wrap, wreath, garland, pathway, accent, other
  pricing_unit pricing_unit not null default 'each',
  unit_price   numeric not null default 0,
  bulb_type    text,                 -- C9, C7, mini, LED…
  color        text,
  size         text,                 -- wreath size, etc.
  spacing      text,                 -- "12in", "15in"
  active       boolean not null default true,
  notes        text,
  created_at   timestamptz not null default now()
);
create index on product_catalog (org_id);

-- A property's lighting design for a given season. "Renew" clones it to next year.
create table designs (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  property_id uuid not null references properties(id) on delete cascade,
  job_id      uuid references jobs(id) on delete set null,
  season_year int not null,
  status      design_status not null default 'draft',
  notes       text,
  created_at  timestamptz not null default now()
);
create index on designs (org_id);
create index on designs (property_id);

-- The measured sections of a design. Each snapshots the catalog product + price
-- so past designs/quotes don't shift if the price book changes later.
create table design_sections (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  design_id     uuid not null references designs(id) on delete cascade,
  catalog_id    uuid references product_catalog(id) on delete set null,
  label         text not null,        -- location: "Front roofline", "Oaks by driveway"
  product_name  text not null,        -- snapshot of catalog name
  pricing_unit  pricing_unit not null default 'each',
  quantity      numeric not null default 0,  -- feet / strands / 9ft sections / count
  unit_price    numeric not null default 0,  -- snapshot rate (overridable)
  bulb_type     text,
  color         text,
  power_circuit text,                  -- which circuit/outlet feeds this run
  notes         text,
  sort          int not null default 0,
  created_at    timestamptz not null default now()
);
create index on design_sections (org_id);
create index on design_sections (design_id);

-- Power plan: outlets/circuits at a property and their load, so installs don't
-- trip breakers.
create table circuits (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  property_id     uuid not null references properties(id) on delete cascade,
  label           text not null,      -- "Front porch GFCI", "Garage exterior"
  outlet_location text,
  amps            numeric,            -- breaker rating
  timer           text,               -- timer/photocell notes
  notes           text,
  created_at      timestamptz not null default now()
);
create index on circuits (org_id);
create index on circuits (property_id);

-- Extend the existing fixtures table into the customer-owned-but-LUX-stored
-- materials record. Customer buys it, LUX stores it off-season, customer can
-- reclaim it anytime.
alter table fixtures add column if not exists catalog_id uuid references product_catalog(id) on delete set null;
alter table fixtures add column if not exists status material_status not null default 'in_storage';
alter table fixtures add column if not exists storage_location text;
alter table fixtures add column if not exists purchased_on date;
alter table fixtures add column if not exists returned_on date;
alter table fixtures alter column owned_by_client set default true;

-- RLS for the new tables (same per-org scoping as everything else).
alter table product_catalog enable row level security;
alter table designs         enable row level security;
alter table design_sections enable row level security;
alter table circuits        enable row level security;

create policy product_catalog_rw on product_catalog
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy designs_rw on designs
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy design_sections_rw on design_sections
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());
create policy circuits_rw on circuits
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());

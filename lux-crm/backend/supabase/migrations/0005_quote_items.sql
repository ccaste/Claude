-- Phase 3: quote-builder redesign. Rich line items (item type, area, light type,
-- color) that flow quote → invoice → storage, plus per-org item defaults.

create type item_type as enum (
  'roofline','roof_ridge','ground_lights','bushes','tree_wrap',
  'tree_canopy','edges','wreaths','garland','other'
);
create type light_type as enum ('mini','c7','c9','none');

-- Enrich quote + invoice line items with the lighting detail.
alter table quote_line_items   add column if not exists item_type  item_type;
alter table quote_line_items   add column if not exists area       text;
alter table quote_line_items   add column if not exists light_type light_type;
alter table quote_line_items   add column if not exists color      text;
alter table quote_line_items   add column if not exists unit       text;

alter table invoice_line_items add column if not exists item_type  item_type;
alter table invoice_line_items add column if not exists area       text;
alter table invoice_line_items add column if not exists light_type light_type;
alter table invoice_line_items add column if not exists color      text;
alter table invoice_line_items add column if not exists unit       text;

-- Per-org defaults for each item type (price / light / color / unit).
create table item_defaults (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references organizations(id) on delete cascade,
  item_type          item_type not null,
  label              text not null,
  default_light_type light_type,
  default_color      text,
  default_unit       text not null default 'each',
  default_unit_price numeric not null default 0,
  sort               int not null default 0,
  unique (org_id, item_type)
);
create index on item_defaults (org_id);
alter table item_defaults enable row level security;
create policy item_defaults_rw on item_defaults
  for all using (org_id = auth_org_id()) with check (org_id = auth_org_id());

-- Enrich storage records (fixtures) with the same detail so items carry through.
alter table fixtures add column if not exists item_type  item_type;
alter table fixtures add column if not exists area       text;
alter table fixtures add column if not exists light_type light_type;
alter table fixtures add column if not exists color      text;

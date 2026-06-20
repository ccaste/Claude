-- Light type now drives unit (foot vs set) and spacing; defaults vary by
-- (item type, light type). Add spacing throughout and re-key item_defaults.

-- Spacing on items + storage.
alter table quote_line_items   add column if not exists spacing text;
alter table invoice_line_items add column if not exists spacing text;
alter table fixtures           add column if not exists spacing text;

-- item_defaults: add light_type + default_spacing, re-key on (org, item, light).
alter table item_defaults add column if not exists light_type      light_type;
alter table item_defaults add column if not exists default_spacing text;

-- Backfill existing rows (old schema had one row per item type).
update item_defaults set light_type = default_light_type
  where light_type is null and default_light_type is not null;

alter table item_defaults drop constraint if exists item_defaults_org_id_item_type_key;
do $$ begin
  alter table item_defaults
    add constraint item_defaults_org_item_light_key unique (org_id, item_type, light_type);
exception when others then null; end $$;

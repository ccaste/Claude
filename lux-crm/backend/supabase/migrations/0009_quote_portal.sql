-- Customer-facing quote portal: a public token per quote (used in the link we
-- send), plus a server-side accept_quote() that creates the job + invoice +
-- storage atomically. Called by the portal Edge Function (service role) when a
-- customer accepts.

alter table quotes add column if not exists public_token  uuid not null default gen_random_uuid();
alter table quotes add column if not exists accepted_at   timestamptz;
alter table quotes add column if not exists customer_note text;
create unique index if not exists quotes_public_token_idx on quotes(public_token);

create or replace function accept_quote(p_quote uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  q        quotes%rowtype;
  v_job    uuid;
  v_invoice uuid;
  v_season int;
begin
  select * into q from quotes where id = p_quote;
  if not found then raise exception 'quote not found'; end if;

  v_season := case when extract(month from now()) >= 6
                   then extract(year from now())::int
                   else extract(year from now())::int - 1 end;

  update quotes set status = 'approved', accepted_at = now() where id = p_quote;

  -- Resolve the job: reuse the originating request, or create one.
  if q.job_id is not null then
    update jobs set status = 'approved' where id = q.job_id;
    v_job := q.job_id;
  else
    insert into jobs (org_id, client_id, property_id, title, service_type, status, season_year)
    values (q.org_id, q.client_id, q.property_id, 'Christmas ' || v_season::text,
            'christmas_lighting', 'approved', v_season)
    returning id into v_job;
    update quotes set job_id = v_job where id = p_quote;
  end if;

  -- Invoice from the quote.
  insert into invoices (org_id, client_id, job_id, quote_id, number, status, issued_at,
                        subtotal, tax, total, deposit_amount)
  values (q.org_id, q.client_id, v_job, p_quote,
          'INV-' || floor(extract(epoch from now()))::text, 'sent', current_date,
          q.subtotal, q.tax, q.total, coalesce(q.deposit_amount, 0))
  returning id into v_invoice;

  insert into invoice_line_items (invoice_id, item_type, area, light_type, color, spacing,
                                  description, quantity, unit, unit_price, taxable, sort)
  select v_invoice, item_type, area, light_type, color, spacing,
         description, quantity, unit, unit_price, taxable, sort
  from quote_line_items where quote_id = p_quote order by sort;

  -- Items the customer owns now live in storage for the property.
  if q.property_id is not null then
    insert into fixtures (org_id, property_id, category, description, quantity, unit,
                          item_type, area, light_type, color, spacing, owned_by_client, status)
    select q.org_id, q.property_id, coalesce(item_type::text, 'other'),
           description, quantity, unit, item_type, area, light_type, color, spacing, true, 'in_storage'
    from quote_line_items where quote_id = p_quote;
  end if;

  return v_job;
end;
$$;

grant execute on function accept_quote(uuid) to service_role;

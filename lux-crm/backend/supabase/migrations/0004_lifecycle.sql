-- Phase 2b: encode the full Christmas-season customer lifecycle.
--
-- A "job" is the opportunity that flows through every phase:
--   lead → quoted → approved → partially_installed → installed
--        → ready_for_takedown → stored   (or declined / cancelled)
--
-- Run the ALTER TYPE ... ADD VALUE lines first; if the editor complains about a
-- transaction, run them one at a time.

-- New lifecycle phases (existing values: lead, quoted, approved, scheduled,
-- in_progress, completed, on_hold, cancelled).
alter type job_status add value if not exists 'partially_installed';
alter type job_status add value if not exists 'installed';
alter type job_status add value if not exists 'ready_for_takedown';
alter type job_status add value if not exists 'stored';
alter type job_status add value if not exists 'declined';

-- Visit types for the season (existing: consult, install, service,
-- maintenance, removal).
alter type visit_kind add value if not exists 'greenery';
alter type visit_kind add value if not exists 'takedown';

-- Appointments can be virtual or in person.
do $$ begin
  create type visit_mode as enum ('in_person', 'virtual');
exception when duplicate_object then null; end $$;

alter table visits add column if not exists mode visit_mode;

-- Deposits: required on a quote at acceptance, collected against the invoice.
alter table quotes add column if not exists deposit_required boolean not null default false;
alter table quotes add column if not exists deposit_amount   numeric not null default 0;
alter table quotes add column if not exists approved_at      timestamptz;
alter table quotes add column if not exists declined_at      timestamptz;

alter table invoices add column if not exists deposit_amount numeric not null default 0;

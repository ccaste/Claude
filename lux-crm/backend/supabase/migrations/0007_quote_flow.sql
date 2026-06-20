-- Quotes are first-class: they can be sent, and a customer can request changes.
-- A job is only created when a quote is accepted.

alter type quote_status add value if not exists 'changes_requested';

alter table quotes add column if not exists sent_at timestamptz;

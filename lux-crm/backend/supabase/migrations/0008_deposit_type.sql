-- Deposit can be a fixed dollar amount or a percentage of the quote total.
-- deposit_amount stays the resolved dollar figure (what carries to the invoice).
alter table quotes add column if not exists deposit_type    text not null default 'amount'; -- 'amount' | 'percent'
alter table quotes add column if not exists deposit_percent numeric not null default 0;

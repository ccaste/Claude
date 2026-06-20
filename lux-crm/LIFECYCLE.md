# Customer & Job Lifecycle

A job is the opportunity that flows through the whole season. One record, many
phases — this is the process the app enforces.

```
  ┌────────┐  generate   ┌────────┐  accept quote   ┌──────────────────────┐
  │  LEAD  │ ──quote───▶ │ QUOTED │ ──(+deposit)──▶ │ APPROVED – ready to   │
  └────────┘             └────────┘                 │ install (invoice made)│
      │  decline               │  decline           └──────────┬───────────┘
      ▼                        ▼                                │ install begins
  ┌──────────┐                                                  ▼
  │ DECLINED │                                   ┌───────────────────────────┐
  └──────────┘                                   │ PARTIALLY INSTALLED        │
                                                  └──────────┬────────────────┘
                                                             │ install complete
                                                             ▼
                                              ┌──────────────────────────────┐
                                              │ INSTALLED – in maintenance     │
                                              │ (balance can be collected)     │
                                              └──────────┬─────────────────────┘
                                                         │ season ending
                                                         ▼
                                              ┌──────────────────────────────┐
                                              │ READY FOR TAKE DOWN            │
                                              └──────────┬─────────────────────┘
                                                         │ take-down done
                                                         ▼
                                              ┌──────────────────────────────┐
                                              │ TAKEN DOWN & STORED            │
                                              │ (ready for next season)        │
                                              └────────────────────────────────┘
```

## The 11 steps, mapped

1. **Interest → Lead.** Create a lead with a client + property attached. → status `lead`
2. **Appointment.** Add an appointment to the job, **virtual or in person**. → a `consult` visit with a `mode`
3. **Quote.** Build the design on the property, Generate Quote. → status `quoted`
4. **Accept / Decline.** Accept turns it into a job (`approved`); decline → `declined`.
5. **Items to install.** The accepted quote's line items copy into an invoice; the design sections are what gets installed.
6. **Visits.** Schedule visits of kind **installation, greenery, maintenance, take down**.
7. **Invoice.** Created automatically when the quote is accepted (alongside the job).
8. **Deposit.** On acceptance you can require a deposit; it's a payment against the invoice.
9. **Balance.** Collected once installed — doesn't wait for take down. (`installed` phase; record payment.)
10. **Maintenance.** Maintenance visits address issues during the season.
11. **Take down.** End of season → take-down visits → `stored`, ready for next year.

## Where each lives in the app

- **Jobs tab** → filter by stage (All / Leads / Active / Closed); **+** creates a lead.
- **Job detail** → change phase, add appointments & visits, accept/decline quotes, see the invoice, record deposit & balance payments.
- **Clients → property → design** → build the design and generate the quote.

# LUX CRM

A field-service CRM for **LUX Lighting Services** (Christmas + landscape lighting),
built to replace Jobber. Native iPhone app (SwiftUI) backed by Supabase.

This is **Phase 1: the foundation** — the data model, team auth, and the core
CRM screens. It is not yet the full Jobber replacement; see the roadmap below.

## What's here today

- **Database** (`backend/`) — complete Postgres schema for clients, multi-year
  property profiles, jobs with paired install/removal visits, per-property light
  & fixture inventory, quotes, invoices, payments, time tracking, and a message
  log. Team access is enforced with row-level security.
- **iPhone app** (`ios/`) — SwiftUI app with email/password login, a Today
  dashboard, a day schedule, client list + detail + add, and a jobs list. All
  wired to Supabase with the team-permission model.

## Architecture

```
  iPhone app (SwiftUI)
        │  HTTPS, anon key + user JWT
        ▼
  Supabase
   ├─ Postgres + Row-Level Security   (data, per-org isolation)
   ├─ Auth                            (team logins & roles)
   ├─ Storage                         (property/install photos — Phase 2)
   └─ Edge Functions                  (Stripe, email/SMS — Phase 3)
        │
        ├─ Stripe        (card payments)
        ├─ Resend        (email: quotes, invoices, reminders)
        └─ Twilio        (SMS reminders)
```

Why this stack: you have a Mac + Xcode, want it on iPhone, and need a team with
sync — so a native app + a managed backend (no server to run) is the fastest
path. The anon key is safe to ship because RLS, not the app, guards the data.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| **1. Foundation** | Schema + RLS, auth, dashboard, clients, jobs, schedule | ✅ this PR |
| **2. Core CRM** | Property & fixture editing, job creation, visit scheduling (install+removal pairs), photos, edit/archive clients, month calendar | next |
| **3. Money** | Quotes → approval → invoice flow, PDF generation, Stripe payments (Edge Function), email/SMS reminders | |
| **4. Field & polish** | Time tracking, offline cache, push notifications, crew permissions, reporting, recurring annual jobs | |

## Cost vs Jobber

- **Supabase** — free to start, ~$25/mo (Pro) once you have real data/photos.
- **Stripe** — per-transaction (~2.9% + 30¢), no monthly fee.
- **Twilio** — ~1¢/SMS; **Resend** — free tier covers low volume.
- **Apple Developer** — $99/yr to install on phones / ship to the App Store.

Roughly **$25/mo + usage** vs Jobber's ~$100–250/mo.

## Getting started

1. Set up the backend → [`backend/README.md`](backend/README.md)
2. Build the app → [`ios/README.md`](ios/README.md)

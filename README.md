# Qvrix Luxe — Super Admin Console

Flutter Web console for monitoring every salon on the Qvrix Luxe platform.
Independent of the Salon CRM frontend; reads the **same** Firebase project
(`crmapp-1299dddb`) through its own web app registration.

## Prerequisites

Two backend changes must be deployed **from the `SpaCRM` repo** before the
console can read anything. Until they are, every screen shows
`permission-denied`.

```bash
cd ../SpaCRM
firebase deploy --only firestore:rules,firestore:indexes
```

- **Rules** add `match /{path=**}/<col>/{id}` collection-group reads restricted
  to `isAdmin()`. Without them, cross-salon queries are denied — the per-salon
  rules do *not* authorize a `collectionGroup()` query.
- **Indexes** back the date-range and status filters. A missing index surfaces
  as `failed-precondition`; the console's error state says so explicitly.

## Granting access

The console authenticates as an ordinary Firebase user. Access is granted by
the user's Firestore profile, not by anything in this app:

```
users/{uid}  ->  { role: "super_admin" }
```

Set that field in the Firebase console for each administrator. Any other value
(or a missing profile) is refused at both the router and the database.

## Run

```bash
flutter run -d chrome        # development
flutter build web --release  # production -> build/web
```

## Architecture

```
lib/
  app/          router (route guards), shell (sidebar/topbar), theme
  core/         constants, state, date/format utils, shared widgets
  features/
    auth/       data | domain | presentation
    dashboard/  data (aggregations) | domain (metrics) | presentation
    salons/     data (paging, suspend) | domain | presentation
    analytics/  data (catalog tallies) | presentation (module pages)
    audit/      data (append-only log) | presentation
    settings/   presentation
```

Repository pattern under `data/`, immutable models under `domain/`, Riverpod
providers + widgets under `presentation/`.

## How the analytics stay cheap

Every KPI is a Firestore **server-side aggregation** (`count()`, `sum()`), which
returns a scalar without transferring documents — dashboard cost is independent
of table size. Trends bucket a window into <= ~30 aggregations (daily under 31
days, rolled up beyond). Salon lists use cursor pagination
(`startAfterDocument`) with a server `limit`. Providers are `autoDispose` +
`keepAlive`, so navigating away and back reuses results instead of re-querying.
There are no realtime listeners except the single salon document on its detail
page.

### Known limit

`Top services` and `Staff utilisation` need a GROUP BY, which Firestore does not
have. They read a **bounded, date-filtered sample (3000 bookings)** and tally it
client-side; the chart labels the figures as a sample when the cap is hit. For
exact numbers at scale, maintain a rollup document from a Cloud Function on
appointment writes (requires the Blaze plan) and read that instead.

## Security

- No service-account or admin credential exists in this frontend. The web API
  key is public by design; Security Rules are the boundary.
- Route guards are convenience only — removing them grants no data.
- Role is always read from `users/{uid}`, never cached or inferred. A missing
  profile fails closed.
- Suspend/reactivate writes an `adminAuditLogs` row; rules deny `update` and
  `delete` on that collection, so history cannot be rewritten by anyone.
- `salons/{id}.status` is writable only by a super admin. An **absent** status
  means active, so salons created before this console are unaffected.

Verified in the Firestore emulator against the real rules: 24/24 checks,
covering admin access, owner/anonymous denial, unchanged CRM behaviour,
suspension authority, and audit-log immutability.

## Not implemented

**Memberships.** The CRM has no membership collection or field, so there was
nothing to report on. It needs to be designed and built in the CRM first.

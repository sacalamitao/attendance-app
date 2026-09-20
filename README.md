# Church Attendance PWA

A Progressive Web App for managing church attendees, events and QR-code attendance
scanning, with live attendance dashboards and downloadable Excel reports.

```
Admin login → Manage attendees → Attendee receives unique QR → Create event →
Open event → Scan QR codes → Live dashboard → Close event → Download .xlsx report
```

The backend is the sole authority for every business rule. The frontend renders
what the server decides and never determines whether a scan is valid.

---

## Stack

| Layer | Choice |
| --- | --- |
| Backend | Ruby on Rails 8.1, PostgreSQL |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS, importmap |
| Auth | Devise (sessions), Pundit (authorization) |
| QR | `rqrcode` server-side generation; `BarcodeDetector` with a vendored `jsQR` fallback for decoding |
| Excel | `caxlsx` (real `.xlsx` workbooks) |
| Tests | RSpec, FactoryBot, Capybara, `roo` for reading generated workbooks |

Hotwire was chosen over a separate React SPA because the repository was already a
Rails 8 app with Turbo, Stimulus, Tailwind and importmap configured. A JSON API
still exists under `/api` and is what the scanner and any future native client use.

---

## Getting started

```bash
bin/setup                 # installs gems, prepares the database, starts the server
bin/rails db:seed         # admin + sample attendees/events (development)
bin/dev                   # Rails server + Tailwind watcher
bundle exec rspec         # full test suite
bin/ci                    # lint, security scans and tests, as CI runs them
```

Development sign-in after seeding:

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@example.com` | `password123!` |
| Operator | `operator@example.com` | `password123!` |

In production, seeds create an administrator only when `ADMIN_EMAIL` and
`ADMIN_PASSWORD` are set. There is no self-service registration; accounts are
provisioned by an administrator.

### Environment

| Variable | Purpose |
| --- | --- |
| `APP_TIME_ZONE` | Congregation time zone; drives scan timestamps and what "today" means for ages. Defaults to `Asia/Manila`. |
| `APP_HOST` | Host used to build password-reset links in production. |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME` | Seed the initial administrator in production. |
| `DEVISE_MAILER_SENDER` | From address for Devise mail. |

Browsers are restricted to modern versions (`allow_browser versions: :modern`),
inherited from the Rails default. The app genuinely needs it: import maps and
Tailwind 4 output both require a recent browser. Older devices get the
`406-unsupported-browser` page.

---

## Domain rules

### Ministry classification

Classification is **derived, never stored on the attendee and never user-editable**.
All rules live in one place, `MinistryClassifier`:

| Age on the relevant date | Ministry |
| --- | --- |
| 13–21 | KKB |
| 22–28 | YAN |
| 29+ male | Men's |
| 29+ female | Women's |
| under 13 | unsupported — rejected with a validation error |

Adding a ministry means adding a rule to `MinistryClassifier::RULES`, a code to
`Ministry::ALL` and a value to the database check constraint. Nothing else changes.

### Historical accuracy

Attendance rows store a **snapshot** of the classification computed from the
attendee's birthdate and gender as of the *event date*. If someone attended at 28
as YAN and later turns 29, that attendance row and every report built from it
still says YAN. Present attendees in dashboards and reports always use the
snapshot; absent attendees are classified as of the event date, so a closed
event's numbers never drift.

### The core invariant

> One attendee can have at most one attendance record for one event.

Enforced at three levels:

1. A unique index on `(event_id, attendee_id)` — the actual guarantee.
2. A model uniqueness validation — friendly errors in the common case.
3. `RecordAttendance` catches `RecordNotUnique` and resolves the race to a
   duplicate result rather than an error.

A spec drives six real threads at the same QR code and asserts exactly one row is
created and five duplicate results are returned.

### Event lifecycle

`draft → open → closed`, one way only. Reversals are rejected by `OpenEvent` and
`CloseEvent`, not by hiding buttons. A scan takes a `FOR SHARE` lock on the event
row and `CloseEvent` takes `FOR UPDATE`, so a scan can never commit after a close
has committed.

---

## Architecture

```
app/
  controllers/          thin HTTP layer; HTML controllers + Api:: JSON controllers
  models/               persistence, validations, Ministry/Gender vocabularies
  services/             MinistryClassifier, RecordAttendance, OpenEvent,
                        CloseEvent, GenerateEventAttendanceReport
  queries/              EventDashboardQuery, Paginator
  policies/             Pundit policies (server-side authorization)
  serializers/          JSON shapes
  javascript/           Stimulus controllers + the API fetch wrapper
```

Notable pieces:

- **`RecordAttendance`** is the one place a scan is validated. It returns a
  `Result` carrying a status (`recorded`, `duplicate`, `attendee_not_found`,
  `attendee_inactive`, `event_closed`, `event_not_open`, `unsupported_age`,
  `unauthorized`), a human message and the right HTTP status.
- **`EventDashboardQuery`** aggregates with SQL rather than loading records.
  Per-ministry absent counts are four indexed `COUNT`s, not an in-Ruby scan.
- **`Paginator`** is a small offset paginator, added instead of a pagination gem
  because the current `pagy` release is incompatible with this Rails version.

### Roles

| Action | Admin | Operator |
| --- | :---: | :---: |
| View attendees, events, dashboards | ✅ | ✅ |
| Create/edit attendees and events | ✅ | ❌ |
| Open / close events | ✅ | ❌ |
| Scan attendance (open events only) | ✅ | ✅ |
| Download reports (closed events only) | ✅ | ❌ |

Every protected endpoint authorizes server-side; controllers use Pundit's
`verify_authorized`. Hiding a button is never the control.

---

## API

All endpoints are session-authenticated and expect `X-CSRF-Token`. Unauthenticated
requests get `401`; unauthorized ones get `403` with a machine-readable code.

```http
GET    /api/attendees            POST   /api/attendees
GET    /api/attendees/:id        PATCH  /api/attendees/:id
DELETE /api/attendees/:id        (deactivates; never hard-deletes)
GET    /api/attendees/:id/qr     GET    /api/attendees/:id/attendance

GET    /api/events               POST   /api/events
GET    /api/events/:id           PATCH  /api/events/:id
POST   /api/events/:id/open      POST   /api/events/:id/close

POST   /api/events/:id/attendance/scan
GET    /api/events/:id/attendance
GET    /api/events/:id/attendance/dashboard
GET    /api/events/:id/report            → .xlsx download

GET    /api/classification?birthdate=&gender=   → ministry preview for forms
```

### Scan

```http
POST /api/events/42/attendance/scan
{ "qr_token": "attendee:kP3n…" }
```

```jsonc
// 201 Created
{
  "status": "recorded",
  "message": "Attendance recorded.",
  "present_count": 128,
  "attendee": { "id": 42, "full_name": "John Doe", "age": 24, "gender": "male",
                "ministry_classification": "yan", "ministry_label": "YAN" },
  "attendance": { "id": 123, "scanned_at": "2026-09-20T09:04:32+08:00",
                  "scanned_at_label": "9:04 AM" }
}
```

A repeat scan returns `200` with `"status": "duplicate"`, the original
`scanned_at` untouched and no new row. The operator is always taken from the
session, never from the request body.

---

## Security

- QR codes encode `attendee:<24-byte urlsafe random token>` and nothing else. No
  name, birthdate or database id. The server resolves the token to an attendee;
  a QR payload is never treated as proof of authorization.
- Tokens are unique-indexed and stable until explicitly regenerated.
- Every attendance row records `operator_id` from the authenticated session, for
  accountability when several people scan at once.
- The scan endpoint is rate-limited to 300 requests/minute per client.
- Devise locks an account after 10 failed sign-ins for 15 minutes.
- `force_ssl` and `assume_ssl` are on in production: `getUserMedia` and service
  workers both require a secure context.
- Brakeman reports zero warnings.

---

## PWA and offline behavior

The app is installable: a web manifest, a service worker, maskable icons,
standalone display and a mobile-first responsive layout.

The service worker caches the app shell and fingerprinted assets, and serves a
cached page or `/offline` when a navigation fails. **It deliberately never caches
or queues attendance writes.** `/api`, `/cable` and auth routes are network-only.

Offline attendance was not implemented, on purpose. A queued scan that later
fails to sync would silently corrupt the attendance record an event's report
depends on. Instead the app is explicit: a banner appears while the browser is
offline, and the scanner shows "No connection — the scan was NOT saved" rather
than a success state. Correctness is preferred over pretending a scan succeeded.
The building blocks for a future offline mode (server-side duplicate prevention
and an idempotent scan endpoint) are already in place.

## Scanner

Optimized for scanning many codes in a row during a live service: continuous
decoding at ~10 fps with no "scan next" button, a per-code cooldown so one badge
held in frame is not resubmitted, colour **and text** feedback for every outcome,
haptic feedback, and a live present count. Camera permission denial, missing
cameras, insecure contexts and a camera busy in another app each get a specific
message. A manual-entry fallback is available when the camera cannot be used.
Camera frames are decoded in memory only; no image or video is ever stored.

---

## Reports

`GET /events/:id/report` (or the API equivalent) returns a real `.xlsx` workbook,
available only once the event is closed.

- **Sheet 1 — Event Summary**: name, date, start/end time, location, status,
  totals (registered / present / absent / percentage) and the per-ministry table.
- **Sheet 2 — Attendance Details**: every registered attendee sorted by name,
  with age and ministry as of the event date, `Present`/`Absent`, and the scan
  timestamp for those present.

Percentages are written as real Excel percentage-formatted numbers, and division
by zero is handled (an event with no attendees reports 0%).

---

## Testing

```bash
bundle exec rspec
```

155 examples covering age boundaries and birthday transitions (including Feb 29),
QR uniqueness and opacity, event state transitions, duplicate and concurrent
scans, the classification snapshot, dashboard aggregation and zero-division,
report contents read back out of the generated workbook, the full authorization
matrix for both roles, and an end-to-end workflow spec from login to report
download.

---

## Assumptions

Documented decisions where the specification left room:

1. **Two roles**, admin and operator. Operators scan and view; admins manage
   attendees, events and reports.
2. **Registration is disabled.** Accounts are provisioned by an administrator.
3. **"Registered attendees"** for a given event means all active attendees, plus
   anyone already marked present. Deactivating someone after they attended never
   removes them from that event's totals.
4. **Deletion is soft.** Deactivating keeps attendance history intact and stops
   the QR code from working. Hard deletion is blocked at the association level.
5. **Attendees must be at least 13**, both at creation and on the event date.
   A scan for someone below the supported range is rejected rather than
   silently classified.
6. **Live updates** use Turbo Stream refreshes over Action Cable, with a 20
   second polling fallback, so no extra infrastructure is required.
7. **`json` is pinned to 2.x.** Version 3.0 removed the positional options
   argument from `JSON.parse`, which Rails 8.1 still uses when deserializing
   encrypted cookies; the pin can be lifted once Rails supports json 3.

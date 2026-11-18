# LevelSet Cross-Device Screen Time Banking — Web Ecosystem

Extends the LevelSet iOS app so screen time earned through exercise can be
spent (and enforced) on a laptop/desktop browser too.

## Pieces

- **`supabase/schema.sql`** — Paste into the Supabase SQL editor. Safe to
  re-run; it also migrates a database created by the older device-id
  version. Creates `profiles`, `device_tokens`, `pairing_sessions` and
  `blocked_websites`, all with RLS enabled.
- **`nextjs-dashboard/`** — Next.js (App Router) site, deploy to Vercel.
  Every API call except starting/confirming a pairing needs an
  `Authorization: Bearer <device token>` header (see *Auth* below).
  - `/pair` — shows a QR code the iOS app scans to link this browser.
  - `POST /api/pair` — starts a pairing session; returns a QR secret (for
    the phone) and a poll secret (kept by this browser).
  - `POST /api/pair/confirm` — called by the iOS app after it scans the QR.
    A first-time phone sends no token and gets a new profile plus its
    phone token; a paired phone sends its token to link another browser.
  - `POST /api/pair/status` — polled by `/pair` with the poll secret; once
    the phone confirms, returns a browser token exactly once and deletes
    the session.
  - `POST /api/sync-balance` — phone only; sets `remaining_seconds` (the
    phone is the source of truth for time earned).
  - `POST /api/sync-stats` — phone only; mirrors XP, streak and challenge
    history to `profiles.xp` / `current_streak` / `stats`.
  - `POST /api/deduct-time` — browser only; subtracts seconds from the
    balance (the desktop is the source of truth for time spent).
  - `GET /api/status` — browser only; returns balance + blocked domains.
  - `GET/POST/DELETE /api/blocked-websites` — browser only; list, add or
    remove blocked domains. Backs `/dashboard`.
  - `DELETE /api/account` — phone only; deletes the profile and, through
    cascades, every token, blocked site and pairing session.
  - `DELETE /api/token` — revokes the calling device's own token
    ("Unlink this browser" on `/dashboard`).
  - `/dashboard` — shows the balance and manages blocked domains using the
    browser token saved by `/pair`.
  - `/locked` — shown when the balance hits 0.
- **`browser-extension/`** — Manifest V3 Chrome/Safari extension.
  Polls `/api/status`, times restricted sites, calls `/api/deduct-time`
  every 5s while one is active, and redirects to `/locked` at 0.
- **iOS app** (`LevelSet/Services/DesktopSyncService.swift`,
  `LevelSet/Views/Account/{QRScannerView,LinkDesktopView}.swift`) — a
  "Link Desktop" row on the Profile screen opens a QR scanner; scanning
  the `/pair` code calls `/api/pair/confirm` and stores the returned
  phone token in the Keychain (`KeychainStore`). Every change to the
  earned-time budget (`UserProgress.grantBonusMinutes` /
  `setDailyLimit`) calls `/api/sync-balance` in the background. XP,
  streak, and history are also persisted locally (`PersistenceStore`)
  and pushed via `/api/sync-stats` whenever a challenge completes,
  onboarding finishes, or the app is backgrounded. Deleting the account
  on the Profile screen calls `DELETE /api/account` (retried on the next
  launch if the phone was offline).

## Setup

1. **Supabase**: create a project, run `supabase/schema.sql` in the SQL
   editor, then copy the Project URL and `service_role` key from
   Settings → API.
2. **Next.js dashboard** (Node.js 20.9 or later):
   ```
   cd nextjs-dashboard
   cp .env.example .env.local   # fill in the two Supabase values
   npm install
   npm run dev
   ```
   Deploy to Vercel and set the same two environment variables in the
   project's Vercel settings (`NEXT_PUBLIC_SUPABASE_URL`,
   `SUPABASE_SERVICE_ROLE_KEY`).
3. **Browser extension**:
   - Edit `browser-extension/config.js` → set `API_BASE_URL` to your
     deployed Vercel URL.
   - Edit `browser-extension/manifest.json` → update `host_permissions`
     to match the same URL.
   - Chrome: `chrome://extensions` → Developer mode → "Load unpacked" →
     select the `browser-extension/` folder.
   - Pair the browser on `/pair`, click **Copy extension key** on the
     "Linked!" screen, and paste it into the extension's options page.
4. **iOS app**: update `DesktopSyncService.baseURL` in
   `LevelSet/Services/DesktopSyncService.swift` to your deployed Vercel
   URL. On the Profile screen, tap **Link Desktop**, scan the QR on
   `/pair`, and the app calls `/api/pair/confirm`. From then on the app
   pushes balance updates via `/api/sync-balance`, and the browser and
   extension read and spend that same balance with their browser token.

## Notes

- The extension never talks to Supabase directly — only to the Vercel
  API routes, which use the service-role key server-side. No Supabase
  key ships inside the extension bundle.
- `remaining_seconds` deduction happens server-side and is floored at
  0, so a compromised or offline client can't push the balance negative.
- **Auth.** Each device gets a random 256-bit token, shown to it once.
  The database stores only its SHA-256 hash (`device_tokens`). A token's
  kind limits what it can do (`lib/auth.js`): the phone token can set the
  balance, sync stats, link browsers and delete the account; a browser
  token can read status, spend time and edit blocked sites, but can never
  add time. The phone token stays in the iOS Keychain and is never shown.
- POST bodies must be `Content-Type: application/json`, so cross-site
  forms can't trigger them.
- Every route validates its input before touching the database. Synced
  balances are capped at 7 days, stats payloads at 64 KB, and each
  profile can restrict up to 200 sites. Pairing sessions expire after 10
  minutes and are deleted once used or expired.
- Phones paired with the older device-id version must pair again. Their
  old profiles are kept; once everyone has re-paired, remove them in the
  Supabase SQL editor:
  ```sql
  delete from public.profiles p
  where p.user_id is not null
    and not exists (select 1 from public.device_tokens t where t.profile_id = p.id);
  alter table public.profiles drop column user_id;
  ```

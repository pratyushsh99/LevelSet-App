# LevelSet Cross-Device Screen Time Banking — Web Ecosystem

Extends the LevelSet iOS app so screen time earned through exercise can be
spent (and enforced) on a laptop/desktop browser too.

## Pieces

- **`supabase/schema.sql`** — Paste into the Supabase SQL editor once.
  Creates `profiles` and `blocked_websites` with RLS enabled.
- **`nextjs-dashboard/`** — Next.js (App Router) site, deploy to Vercel.
  - `/pair` — shows a QR + short code the iOS app scans to link a profile.
  - `POST /api/pair` — issues a new pairing code (called by `/pair` on load).
  - `POST /api/pair/confirm` — called by the iOS app after it scans the QR;
    links the phone's device id to that pairing code's profile.
  - `POST /api/sync-balance` — called by the iOS app whenever its earned
    balance changes; sets `remaining_seconds` to an absolute value (the
    phone is the source of truth for time earned).
  - `POST /api/sync-stats` — called by the iOS app in the background;
    mirrors XP, streak, and challenge history to `profiles.xp` /
    `current_streak` / `stats` so it survives a reinstall or new device.
  - `POST /api/deduct-time` — called by the browser extension; subtracts
    seconds from a profile's balance (the desktop is the source of truth
    for time spent).
  - `GET /api/pair/status?profileId=...` — polled by `/pair` while waiting
    for the phone to scan; reports the resulting device id once linked.
  - `/dashboard` — shows the current balance and lets you add/remove
    blocked domains without touching the Supabase table editor. Identifies
    "your" profile via a device id stored in this browser's localStorage
    (set automatically after `/pair` finishes) or pasted in manually.
  - `GET/POST/DELETE /api/blocked-websites` — list, add, or remove a
    profile's blocked domains; backs the `/dashboard` page.
  - `GET /api/status` — returns balance + blocked domains.
  - `/locked` — shown when the balance hits 0.
- **`browser-extension/`** — Manifest V3 Chrome/Safari extension.
  Polls `/api/status`, times restricted sites, calls `/api/deduct-time`
  every 5s while one is active, and redirects to `/locked` at 0.
- **iOS app** (`LevelSet/Services/DesktopSyncService.swift`,
  `LevelSet/Views/Account/{QRScannerView,LinkDesktopView}.swift`) — a
  "Link Desktop" row on the Profile screen opens a QR scanner; scanning
  the `/pair` code calls `/api/pair/confirm`, and every change to the
  earned-time budget (`UserProgress.grantBonusMinutes` /
  `setDailyLimit`) calls `/api/sync-balance` in the background. XP,
  streak, and history are also persisted locally (`PersistenceStore`)
  and pushed via `/api/sync-stats` whenever a challenge completes,
  onboarding finishes, or the app is backgrounded.

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
   - Open the extension's options page and paste the device id shown on
     the phone's "Desktop linked!" screen (or on `/dashboard`, if this
     browser already picked it up automatically after pairing).
4. **iOS app**: update `DesktopSyncService.baseURL` in
   `LevelSet/Services/DesktopSyncService.swift` to your deployed Vercel
   URL. On the Profile screen, tap **Link Desktop**, scan the QR on
   `/pair`, and the app calls `/api/pair/confirm` to link its device id.
   From then on the app pushes balance updates via `/api/sync-balance`,
   and the extension's saved `userId` (paste the same device id into
   the extension's options page) reads/spends that same balance —
   Realtime is enabled on both tables so a paired dashboard also
   updates live.

## Notes

- The extension never talks to Supabase directly — only to the Vercel
  API routes, which use the service-role key server-side. No Supabase
  key ships inside the extension bundle.
- `remaining_seconds` deduction happens server-side and is floored at
  0, so a compromised or offline client can't push the balance negative.
- The device id works like a password for the API. Every route validates
  ids, pairing codes, domains and numbers before touching the database,
  synced balances are capped at 7 days, stats payloads at 64 KB, and each
  profile can restrict up to 200 sites. Unclaimed pairing codes are cleaned
  up an hour after they expire.

# Security Policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Instead, use
GitHub's **Report a vulnerability** button on the repository's Security tab
to send a private report. Include steps to reproduce and the impact you
expect. You'll get a reply as soon as possible.

## Design notes

- The iOS app's device id is the credential for the web API. Treat it like a
  password: anyone who has it can read and spend that profile's balance.
- Only the Next.js server holds the Supabase service-role key. The iOS app,
  the dashboard in the browser, and the Chrome extension never receive a
  database key.
- Row Level Security is enabled on every table as a second layer.
- All API input is validated server-side: ids, pairing codes, domains and
  numeric values are checked for format and range before any database call.
- Never commit `.env.local` or any Supabase key. Use `.env.example` as the
  template.

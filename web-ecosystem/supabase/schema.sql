create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id                uuid primary key default gen_random_uuid(),
  remaining_seconds integer not null default 0,
  xp                integer not null default 0,
  current_streak    integer not null default 0,
  stats             jsonb,
  updated_at        timestamptz not null default now()
);

alter table public.profiles add column if not exists xp integer not null default 0;
alter table public.profiles add column if not exists current_streak integer not null default 0;
alter table public.profiles add column if not exists stats jsonb;
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'user_id'
  ) then
    alter table public.profiles alter column user_id drop not null;
  end if;
end $$;
alter table public.profiles drop column if exists pairing_code;
alter table public.profiles drop column if exists pairing_expires_at;
alter table public.profiles drop column if exists resolved_user_id;

comment on table public.profiles is
  'One row per LevelSet user; tracks the earned screen-time balance shared across devices.';
comment on column public.profiles.remaining_seconds is
  'Seconds of desktop browsing time the user has earned and not yet spent.';

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

create table if not exists public.device_tokens (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  token_hash   text unique not null,
  kind         text not null check (kind in ('ios', 'browser')),
  created_at   timestamptz not null default now(),
  last_used_at timestamptz
);

comment on table public.device_tokens is
  'SHA-256 hashes of device bearer tokens. The raw token is shown to its device once and never stored.';

create index if not exists device_tokens_profile_id_idx
  on public.device_tokens (profile_id);

create table if not exists public.pairing_sessions (
  id               uuid primary key default gen_random_uuid(),
  qr_secret_hash   text unique not null,
  poll_secret_hash text not null,
  profile_id       uuid references public.profiles(id) on delete cascade,
  expires_at       timestamptz not null,
  created_at       timestamptz not null default now()
);

comment on table public.pairing_sessions is
  'Short-lived desktop pairing attempts. The QR secret is scanned by the phone; the poll secret stays in the browser that started pairing. A row is deleted as soon as the browser collects its token.';

create index if not exists pairing_sessions_expires_at_idx
  on public.pairing_sessions (expires_at);

create table if not exists public.blocked_websites (
  id         serial primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  domain     text not null,
  created_at timestamptz not null default now(),
  unique (profile_id, domain)
);

comment on table public.blocked_websites is
  'Domains (e.g. youtube.com) a profile has restricted on desktop browsers.';

create index if not exists blocked_websites_profile_id_idx
  on public.blocked_websites (profile_id);

alter table public.profiles enable row level security;
alter table public.blocked_websites enable row level security;
alter table public.device_tokens enable row level security;
alter table public.pairing_sessions enable row level security;

drop policy if exists "users read own profile" on public.profiles;
drop policy if exists "users read own blocked sites" on public.blocked_websites;

drop policy if exists "service role full access" on public.profiles;
create policy "service role full access"
  on public.profiles for all to service_role using (true) with check (true);

drop policy if exists "service role full access" on public.blocked_websites;
create policy "service role full access"
  on public.blocked_websites for all to service_role using (true) with check (true);

drop policy if exists "service role full access" on public.device_tokens;
create policy "service role full access"
  on public.device_tokens for all to service_role using (true) with check (true);

drop policy if exists "service role full access" on public.pairing_sessions;
create policy "service role full access"
  on public.pairing_sessions for all to service_role using (true) with check (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'blocked_websites'
  ) then
    alter publication supabase_realtime add table public.blocked_websites;
  end if;
end $$;

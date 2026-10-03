create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id                uuid primary key default gen_random_uuid(),
  user_id           text unique not null,
  remaining_seconds integer not null default 0,
  pairing_code      text unique,
  pairing_expires_at timestamptz,
  resolved_user_id  text,
  xp                integer not null default 0,
  current_streak    integer not null default 0,
  stats             jsonb,
  updated_at        timestamptz not null default now()
);

alter table public.profiles add column if not exists resolved_user_id text;

alter table public.profiles add column if not exists xp integer not null default 0;
alter table public.profiles add column if not exists current_streak integer not null default 0;
alter table public.profiles add column if not exists stats jsonb;

comment on table public.profiles is
  'One row per LevelSet user; tracks the earned screen-time balance shared across devices.';
comment on column public.profiles.remaining_seconds is
  'Seconds of desktop browsing time the user has earned and not yet spent.';
comment on column public.profiles.pairing_code is
  'Short-lived code/token shown as a QR on /pair and scanned by the iOS app to link this profile.';

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

drop policy if exists "service role full access" on public.profiles;
create policy "service role full access"
  on public.profiles
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists "service role full access" on public.blocked_websites;
create policy "service role full access"
  on public.blocked_websites
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists "users read own profile" on public.profiles;
create policy "users read own profile"
  on public.profiles
  for select
  to authenticated
  using (auth.uid()::text = user_id);

drop policy if exists "users read own blocked sites" on public.blocked_websites;
create policy "users read own blocked sites"
  on public.blocked_websites
  for select
  to authenticated
  using (
    profile_id in (
      select id from public.profiles where auth.uid()::text = user_id
    )
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'blocked_websites'
  ) then
    alter publication supabase_realtime add table public.blocked_websites;
  end if;
end $$;

-- Profesor GO — core schema (docs/CONTRACTS.md §2)

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user, created by trigger (see auth_trigger migration)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  role text not null default 'player' check (role in ('player', 'admin')),
  created_at timestamptz default now(),
  collection_completed_at timestamptz
);
comment on table public.profiles is 'Player/admin profile mirrored from auth.users.';

-- ---------------------------------------------------------------------------
-- professors: the collectible characters
-- ---------------------------------------------------------------------------
create table public.professors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  display_name text not null,
  description text,
  rarity text not null check (rarity in ('COMMON', 'RARE', 'EPIC', 'LEGENDARY')),
  sprite_url text,
  active boolean not null default true,
  base_capture_rate numeric not null check (base_capture_rate >= 0 and base_capture_rate <= 1),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
comment on table public.professors is 'Collectible professors. Only active ones count for the collection.';

-- ---------------------------------------------------------------------------
-- nfc_tags: physical tags placed on the fair stands
-- ---------------------------------------------------------------------------
create table public.nfc_tags (
  id uuid primary key default gen_random_uuid(),
  professor_id uuid references public.professors(id) on delete set null,
  tag_identifier text unique not null,
  active boolean not null default true,
  created_at timestamptz default now()
);
comment on table public.nfc_tags is 'NFC tag -> professor mapping. Admin only; never exposed to players.';
-- The unique constraint above already creates the index nfc_tags_tag_identifier_key
-- used by start-encounter lookups, so no extra index on tag_identifier is needed.

-- ---------------------------------------------------------------------------
-- encounters: a scan that opened a capture attempt window
-- ---------------------------------------------------------------------------
create table public.encounters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  professor_id uuid not null references public.professors(id) on delete cascade,
  created_at timestamptz default now(),
  expires_at timestamptz not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'SUCCESS', 'FAILED', 'EXPIRED'))
);
comment on table public.encounters is 'Capture attempts. Written only by Edge Functions (service_role).';

create index encounters_user_id_status_idx on public.encounters (user_id, status);

-- ---------------------------------------------------------------------------
-- captures: one per user+professor
-- ---------------------------------------------------------------------------
create table public.captures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  professor_id uuid not null references public.professors(id) on delete cascade,
  encounter_id uuid references public.encounters(id) on delete set null,
  throw_quality text not null check (throw_quality in ('MISS', 'GOOD', 'GREAT', 'EXCELLENT')),
  captured_at timestamptz default now(),
  unique (user_id, professor_id)
);
comment on table public.captures is 'Successful captures. Written only by resolve_capture_tx (service_role).';

create index captures_user_id_idx on public.captures (user_id);

-- ---------------------------------------------------------------------------
-- app_settings: key/value game configuration
-- ---------------------------------------------------------------------------
create table public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz default now()
);
comment on table public.app_settings is 'Game configuration (encounter_expiration_seconds, throw_bonus, ...).';

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from public, anon, authenticated;

create trigger professors_set_updated_at
  before update on public.professors
  for each row execute function public.set_updated_at();

create trigger app_settings_set_updated_at
  before update on public.app_settings
  for each row execute function public.set_updated_at();

-- Profesor GO — Row Level Security (docs/CONTRACTS.md §3)
--
-- | table        | player                                     | admin      |
-- |--------------|--------------------------------------------|------------|
-- | profiles     | select/update own row (cannot change role) | select all |
-- | professors   | select where active = true                 | CRUD       |
-- | nfc_tags     | no access                                  | CRUD       |
-- | encounters   | select own                                 | select all |
-- | captures     | select own (no insert/update/delete)       | select all |
-- | app_settings | select                                     | CRUD       |
--
-- Captures and encounters are written only by service_role from Edge Functions
-- (service_role bypasses RLS). Anonymous users get nothing: every policy is
-- scoped `to authenticated`.

alter table public.profiles     enable row level security;
alter table public.professors   enable row level security;
alter table public.nfc_tags     enable row level security;
alter table public.encounters   enable row level security;
alter table public.captures     enable row level security;
alter table public.app_settings enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create policy "profiles: players read own row, admins read all"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

create policy "profiles: players update own row"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Players must not touch privileged columns of their own row. The check is a
-- trigger (not a policy) so it works for any update path. Sessions without a
-- JWT subject (postgres seeds, service_role from Edge Functions) are allowed.
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if new.role is distinct from old.role then
      raise exception 'profiles.role cannot be changed by the user' using errcode = '42501';
    end if;
    if new.collection_completed_at is distinct from old.collection_completed_at then
      raise exception 'profiles.collection_completed_at is managed by the server' using errcode = '42501';
    end if;
    if new.id is distinct from old.id or new.email is distinct from old.email then
      raise exception 'profiles.id / profiles.email cannot be changed by the user' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function public.protect_profile_columns() from public, anon, authenticated;

create trigger profiles_protect_columns
  before update on public.profiles
  for each row execute function public.protect_profile_columns();

-- ---------------------------------------------------------------------------
-- professors
-- ---------------------------------------------------------------------------
create policy "professors: players read active, admins read all"
  on public.professors for select
  to authenticated
  using (active = true or (select public.is_admin()));

create policy "professors: admins insert"
  on public.professors for insert
  to authenticated
  with check ((select public.is_admin()));

create policy "professors: admins update"
  on public.professors for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "professors: admins delete"
  on public.professors for delete
  to authenticated
  using ((select public.is_admin()));

-- ---------------------------------------------------------------------------
-- nfc_tags: admin only (players have no policy at all)
-- ---------------------------------------------------------------------------
create policy "nfc_tags: admins full access"
  on public.nfc_tags for all
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ---------------------------------------------------------------------------
-- encounters: read only (own rows / all for admin); writes via service_role
-- ---------------------------------------------------------------------------
create policy "encounters: players read own, admins read all"
  on public.encounters for select
  to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

-- ---------------------------------------------------------------------------
-- captures: read only (own rows / all for admin); writes via service_role
-- ---------------------------------------------------------------------------
create policy "captures: players read own, admins read all"
  on public.captures for select
  to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

-- ---------------------------------------------------------------------------
-- app_settings: everyone authenticated reads, admins write
-- ---------------------------------------------------------------------------
create policy "app_settings: authenticated read"
  on public.app_settings for select
  to authenticated
  using (true);

create policy "app_settings: admins insert"
  on public.app_settings for insert
  to authenticated
  with check ((select public.is_admin()));

create policy "app_settings: admins update"
  on public.app_settings for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "app_settings: admins delete"
  on public.app_settings for delete
  to authenticated
  using ((select public.is_admin()));

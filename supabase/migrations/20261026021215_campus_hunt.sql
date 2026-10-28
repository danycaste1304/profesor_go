-- A professor shares one current location for a server-timed, 30-minute hunt.
-- Assignments are made by an admin; players can only read a fresh active hunt.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.hunt_publishers (
  professor_id uuid primary key references public.professors(id) on delete cascade,
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.hunt_sessions (
  id uuid primary key default gen_random_uuid(),
  professor_id uuid not null references public.professors(id) on delete cascade,
  publisher_id uuid not null references public.profiles(id) on delete cascade,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  stopped_at timestamptz,
  latitude double precision,
  longitude double precision,
  accuracy_m double precision,
  located_at timestamptz,
  constraint hunt_sessions_duration_check check (ends_at = started_at + interval '30 minutes'),
  constraint hunt_sessions_location_check check (
    (latitude is null and longitude is null and accuracy_m is null and located_at is null)
    or
    (latitude between -90 and 90 and longitude between -180 and 180
      and accuracy_m between 0 and 100 and located_at is not null)
  )
);
create unique index hunt_sessions_one_open_per_professor_idx
  on public.hunt_sessions (professor_id) where stopped_at is null;
create index hunt_sessions_publisher_id_idx on public.hunt_sessions (publisher_id);

create table public.hunt_checkins (
  session_id uuid not null references public.hunt_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tag_id uuid not null references public.nfc_tags(id) on delete restrict,
  checked_in_at timestamptz not null default now(),
  primary key (session_id, user_id)
);
create index hunt_checkins_user_id_idx on public.hunt_checkins (user_id);
create index hunt_checkins_tag_id_idx on public.hunt_checkins (tag_id);

alter table public.hunt_publishers enable row level security;
alter table public.hunt_sessions enable row level security;
alter table public.hunt_checkins enable row level security;

create policy "hunt_publishers: own or admin read"
  on public.hunt_publishers for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "hunt_publishers: admin insert"
  on public.hunt_publishers for insert to authenticated
  with check ((select public.is_admin()));
create policy "hunt_publishers: admin update"
  on public.hunt_publishers for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "hunt_publishers: admin delete"
  on public.hunt_publishers for delete to authenticated
  using ((select public.is_admin()));

create policy "hunt_sessions: publisher admin or fresh active read"
  on public.hunt_sessions for select to authenticated
  using (
    publisher_id = (select auth.uid())
    or (select public.is_admin())
    or (
      stopped_at is null and ends_at > now()
      and located_at > now() - interval '30 seconds'
    )
  );
create policy "hunt_checkins: own or admin read"
  on public.hunt_checkins for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

-- Private functions hold the only write path. The public wrappers exist solely
-- for PostgREST RPC; all authorization happens in the non-exposed schema.
create or replace function private.start_campus_hunt(p_professor_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_session public.hunt_sessions%rowtype;
begin
  if v_user is null then
    raise exception 'LOGIN_REQUIRED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.professors where id = p_professor_id and active) then
    raise exception 'PROFESSOR_NOT_FOUND' using errcode = '22023';
  end if;
  -- Lock the assignment to serialize two simultaneous start requests.
  perform 1 from public.hunt_publishers
    where professor_id = p_professor_id
      and (user_id = v_user or public.is_admin())
    for update;
  if not found then
    raise exception 'NOT_HUNT_PUBLISHER' using errcode = '42501';
  end if;

  select * into v_session from public.hunt_sessions
    where professor_id = p_professor_id and stopped_at is null and ends_at > now();
  if found then
    if v_session.publisher_id <> v_user then
      raise exception 'HUNT_ALREADY_ACTIVE' using errcode = '23505';
    end if;
    return to_jsonb(v_session);
  end if;

  update public.hunt_sessions set
    stopped_at = now(), latitude = null, longitude = null,
    accuracy_m = null, located_at = null
    where professor_id = p_professor_id and stopped_at is null;

  insert into public.hunt_sessions
    (professor_id, publisher_id, started_at, ends_at)
    values (p_professor_id, v_user, now(), now() + interval '30 minutes')
    returning * into v_session;
  return to_jsonb(v_session);
end;
$$;

create or replace function private.update_campus_hunt_location(
  p_session_id uuid, p_latitude double precision,
  p_longitude double precision, p_accuracy_m double precision
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_session public.hunt_sessions%rowtype;
begin
  if v_user is null then
    raise exception 'LOGIN_REQUIRED' using errcode = '42501';
  end if;
  if p_latitude is null or p_longitude is null or p_accuracy_m is null
    or p_latitude not between -90 and 90 or p_longitude not between -180 and 180
    or p_accuracy_m not between 0 and 100 then
    raise exception 'INVALID_LOCATION' using errcode = '22023';
  end if;
  update public.hunt_sessions set
    latitude = p_latitude, longitude = p_longitude,
    accuracy_m = p_accuracy_m, located_at = now()
    where id = p_session_id and publisher_id = v_user
      and stopped_at is null and ends_at > now()
    returning * into v_session;
  if not found then
    raise exception 'HUNT_NOT_ACTIVE' using errcode = '42501';
  end if;
  return to_jsonb(v_session);
end;
$$;

create or replace function private.stop_campus_hunt(p_session_id uuid)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'LOGIN_REQUIRED' using errcode = '42501';
  end if;
  update public.hunt_sessions set
    stopped_at = now(), latitude = null, longitude = null,
    accuracy_m = null, located_at = null
    where id = p_session_id and stopped_at is null
      and (publisher_id = v_user or public.is_admin());
  return found;
end;
$$;

create or replace function private.check_in_campus_hunt(p_tag_identifier text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_tag_id uuid;
  v_professor_id uuid;
  v_session_id uuid;
  v_checked_in_at timestamptz;
  v_already_registered boolean;
begin
  if v_user is null then
    raise exception 'LOGIN_REQUIRED' using errcode = '42501';
  end if;
  if p_tag_identifier is null or length(trim(p_tag_identifier)) not between 1 and 128 then
    raise exception 'INVALID_TAG' using errcode = '22023';
  end if;
  select id, professor_id into v_tag_id, v_professor_id
    from public.nfc_tags where tag_identifier = trim(p_tag_identifier) and active;
  if not found then
    return null; -- Normal capture flow reports unknown/disabled cards.
  end if;
  select id into v_session_id from public.hunt_sessions
    where professor_id = v_professor_id and stopped_at is null
      and started_at <= now() and ends_at > now()
    for update;
  if not found then
    return null; -- The same NFC card still works outside a hunt.
  end if;

  insert into public.hunt_checkins (session_id, user_id, tag_id)
    values (v_session_id, v_user, v_tag_id)
    on conflict (session_id, user_id) do nothing
    returning checked_in_at into v_checked_in_at;
  v_already_registered := not found;
  if v_already_registered then
    select checked_in_at into v_checked_in_at from public.hunt_checkins
      where session_id = v_session_id and user_id = v_user;
  end if;
  return jsonb_build_object(
    'session_id', v_session_id,
    'professor_id', v_professor_id,
    'checked_in_at', v_checked_in_at,
    'already_registered', v_already_registered
  );
end;
$$;

create or replace function public.start_campus_hunt(p_professor_id uuid)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.start_campus_hunt(p_professor_id); $$;
create or replace function public.update_campus_hunt_location(
  p_session_id uuid, p_latitude double precision,
  p_longitude double precision, p_accuracy_m double precision
)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.update_campus_hunt_location(
  p_session_id, p_latitude, p_longitude, p_accuracy_m
); $$;
create or replace function public.stop_campus_hunt(p_session_id uuid)
returns boolean language sql security invoker set search_path = ''
as $$ select private.stop_campus_hunt(p_session_id); $$;
create or replace function public.check_in_campus_hunt(p_tag_identifier text)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.check_in_campus_hunt(p_tag_identifier); $$;

revoke all on table public.hunt_publishers, public.hunt_sessions,
  public.hunt_checkins from public, anon, authenticated;
grant select, insert, update, delete on table public.hunt_publishers to authenticated;
grant select on table public.hunt_sessions, public.hunt_checkins to authenticated;
grant select, insert, update, delete on table public.hunt_publishers,
  public.hunt_sessions, public.hunt_checkins to service_role;

revoke all on function
  private.start_campus_hunt(uuid),
  private.update_campus_hunt_location(uuid, double precision, double precision, double precision),
  private.stop_campus_hunt(uuid),
  private.check_in_campus_hunt(text),
  public.start_campus_hunt(uuid),
  public.update_campus_hunt_location(uuid, double precision, double precision, double precision),
  public.stop_campus_hunt(uuid),
  public.check_in_campus_hunt(text)
  from public, anon, authenticated;
grant execute on function
  private.start_campus_hunt(uuid),
  private.update_campus_hunt_location(uuid, double precision, double precision, double precision),
  private.stop_campus_hunt(uuid),
  private.check_in_campus_hunt(text),
  public.start_campus_hunt(uuid),
  public.update_campus_hunt_location(uuid, double precision, double precision, double precision),
  public.stop_campus_hunt(uuid),
  public.check_in_campus_hunt(text)
  to authenticated;

-- Expired locations are hidden immediately by RLS and physically removed by
-- this minute job even if the publisher closes the app without pressing Stop.
create extension if not exists pg_cron with schema pg_catalog;

create or replace function private.expire_campus_hunts()
returns void language sql security invoker set search_path = ''
as $$
  update public.hunt_sessions set
    stopped_at = ends_at, latitude = null, longitude = null,
    accuracy_m = null, located_at = null
    where stopped_at is null and ends_at <= now();
$$;
revoke all on function private.expire_campus_hunts() from public, anon, authenticated;

select cron.schedule(
  'profesor-go-expire-campus-hunts',
  '* * * * *',
  'select private.expire_campus_hunts()'
);

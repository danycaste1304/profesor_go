-- A printed QR identifies a professor without exposing the reusable code in
-- Postgres or the Data API. Admin rotation replaces the hash in place.
create table public.professor_qr_codes (
  professor_id uuid primary key references public.professors(id) on delete cascade,
  code_hash text not null unique check (code_hash ~ '^[0-9a-f]{64}$'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  rotated_at timestamptz not null default now()
);
alter table public.professor_qr_codes enable row level security;
create policy "professor_qr_codes: admin read"
  on public.professor_qr_codes for select to authenticated
  using ((select public.is_admin()));
revoke all on public.professor_qr_codes from public, anon, authenticated;
grant select on public.professor_qr_codes to authenticated;
grant select, insert, update, delete on public.professor_qr_codes to service_role;

-- Return the printable secret once to an administrator. Rotation invalidates
-- the prior paper code immediately; only its hash remains in the database.
create or replace function public.admin_rotate_professor_qr(p_professor_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_code text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.professors where id = p_professor_id) then
    raise exception 'PROFESSOR_NOT_FOUND' using errcode = '22023';
  end if;
  v_code := rtrim(translate(
    encode(extensions.gen_random_bytes(32), 'base64'), '+/', '-_'), '=');
  insert into public.professor_qr_codes (professor_id, code_hash, active)
    values (p_professor_id, encode(extensions.digest(v_code, 'sha256'), 'hex'), true)
    on conflict (professor_id) do update set
      code_hash = excluded.code_hash, active = true, rotated_at = now();
  return v_code;
end;
$$;
create or replace function public.admin_set_professor_qr_active(
  p_professor_id uuid, p_active boolean
) returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  if p_active is null then
    raise exception 'INVALID_INPUT' using errcode = '22023';
  end if;
  update public.professor_qr_codes set active = p_active
    where professor_id = p_professor_id;
  return found;
end;
$$;
revoke all on function public.admin_rotate_professor_qr(uuid),
  public.admin_set_professor_qr_active(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.admin_rotate_professor_qr(uuid),
  public.admin_set_professor_qr_active(uuid, boolean) to authenticated;

-- Fixed minute and hour buckets keep abuse counters without storing QR values.
create table private.game_attempt_windows (
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('encounter', 'checkin')),
  period text not null check (period in ('minute', 'hour')),
  window_start timestamptz not null,
  attempts integer not null default 0,
  primary key (user_id, kind, period, window_start)
);
revoke all on private.game_attempt_windows from public, anon, authenticated;

create or replace function private.consume_game_attempt(
  p_user_id uuid, p_kind text, p_period text, p_limit integer
) returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  if p_user_id is null or p_kind not in ('encounter', 'checkin')
    or p_period not in ('minute', 'hour') or p_limit < 1 then
    raise exception 'INVALID_ATTEMPT' using errcode = '22023';
  end if;
  insert into private.game_attempt_windows
    (user_id, kind, period, window_start, attempts)
    values (p_user_id, p_kind, p_period, date_trunc(p_period, now()), 1)
    on conflict (user_id, kind, period, window_start)
    do update set attempts = private.game_attempt_windows.attempts + 1
    returning attempts into v_count;
  return v_count <= p_limit;
end;
$$;
revoke all on function private.consume_game_attempt(uuid, text, text, integer)
  from public, anon, authenticated;

-- Apply the same check-in limits to the existing NFC entrypoint.
create or replace function private.check_in_campus_hunt(p_tag_identifier text)
returns jsonb language plpgsql security definer set search_path = '' as $$
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
  if not private.consume_game_attempt(v_user, 'checkin', 'minute', 20)
     or not private.consume_game_attempt(v_user, 'checkin', 'hour', 200) then
    return null;
  end if;
  select id, professor_id into v_tag_id, v_professor_id
    from public.nfc_tags where tag_identifier = trim(p_tag_identifier) and active;
  if not found then return null; end if;
  select id into v_session_id from public.hunt_sessions
    where professor_id = v_professor_id and stopped_at is null
      and started_at <= now() and ends_at > now()
    for update;
  if not found then return null; end if;
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
    'session_id', v_session_id, 'professor_id', v_professor_id,
    'checked_in_at', v_checked_in_at,
    'already_registered', v_already_registered);
end;
$$;

-- One transaction owns credential lookup, throttling, the per-user/professor
-- advisory lock and replacement of prior active encounters.
create or replace function public.start_encounter_tx(
  p_user_id uuid,
  p_tag_identifier text default null,
  p_qr_code text default null,
  p_expiration_seconds integer default 180
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_prof public.professors%rowtype;
  v_tag public.nfc_tags%rowtype;
  v_qr public.professor_qr_codes%rowtype;
  v_enc public.encounters%rowtype;
begin
  if p_user_id is null or
     ((p_tag_identifier is null) = (p_qr_code is null)) or
     p_expiration_seconds not between 10 and 900 then
    raise exception 'INVALID_INPUT' using errcode = '22023';
  end if;
  if not private.consume_game_attempt(p_user_id, 'encounter', 'minute', 10)
     or not private.consume_game_attempt(p_user_id, 'encounter', 'hour', 100) then
    return jsonb_build_object('outcome', 'RATE_LIMITED');
  end if;

  if p_qr_code is not null then
    select * into v_qr from public.professor_qr_codes
      where code_hash = encode(extensions.digest(p_qr_code, 'sha256'), 'hex');
    if not found then return jsonb_build_object('outcome', 'TAG_NOT_FOUND'); end if;
    if not v_qr.active then return jsonb_build_object('outcome', 'TAG_DISABLED'); end if;
    select * into v_prof from public.professors where id = v_qr.professor_id;
  else
    select * into v_tag from public.nfc_tags where tag_identifier = p_tag_identifier;
    if not found then return jsonb_build_object('outcome', 'TAG_NOT_FOUND'); end if;
    if not v_tag.active then return jsonb_build_object('outcome', 'TAG_DISABLED'); end if;
    select * into v_prof from public.professors where id = v_tag.professor_id;
  end if;
  if not found or not v_prof.active then
    return jsonb_build_object('outcome', 'PROFESSOR_DISABLED');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text || ':' || v_prof.id::text, 0));
  if exists (select 1 from public.captures
    where user_id = p_user_id and professor_id = v_prof.id) then
    return jsonb_build_object('outcome', 'ALREADY_CAPTURED');
  end if;
  update public.encounters set status = 'EXPIRED'
    where user_id = p_user_id and professor_id = v_prof.id and status = 'ACTIVE';
  insert into public.encounters (user_id, professor_id, expires_at, status)
    values (p_user_id, v_prof.id,
      now() + make_interval(secs => p_expiration_seconds), 'ACTIVE')
    returning * into v_enc;
  return jsonb_build_object(
    'outcome', 'SUCCESS', 'encounter_id', v_enc.id,
    'expires_at', v_enc.expires_at,
    'professor', jsonb_build_object(
      'id', v_prof.id, 'display_name', v_prof.display_name,
      'rarity', v_prof.rarity, 'sprite_url', v_prof.sprite_url,
      'description', v_prof.description));
end;
$$;
revoke all on function public.start_encounter_tx(uuid, text, text, integer)
  from public, anon, authenticated;
grant execute on function public.start_encounter_tx(uuid, text, text, integer)
  to service_role;

-- A hunt check-in can originate from a physical NFC tag or a printed QR.
alter table public.hunt_checkins alter column tag_id drop not null;
alter table public.hunt_checkins add column qr_professor_id uuid
  references public.professors(id) on delete restrict;
alter table public.hunt_checkins add constraint hunt_checkins_credential_check
  check ((tag_id is null) <> (qr_professor_id is null));

create or replace function private.check_in_campus_hunt_qr(p_qr_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_professor_id uuid;
  v_session_id uuid;
  v_checked_in_at timestamptz;
  v_already_registered boolean;
begin
  if v_user is null then
    raise exception 'LOGIN_REQUIRED' using errcode = '42501';
  end if;
  if p_qr_code is null or p_qr_code !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'INVALID_QR' using errcode = '22023';
  end if;
  if not private.consume_game_attempt(v_user, 'checkin', 'minute', 20)
     or not private.consume_game_attempt(v_user, 'checkin', 'hour', 200) then
    return null;
  end if;
  select professor_id into v_professor_id from public.professor_qr_codes
    where code_hash = encode(extensions.digest(p_qr_code, 'sha256'), 'hex') and active;
  if not found then return null; end if;
  select id into v_session_id from public.hunt_sessions
    where professor_id = v_professor_id and stopped_at is null
      and started_at <= now() and ends_at > now()
    for update;
  if not found then return null; end if;
  insert into public.hunt_checkins (session_id, user_id, qr_professor_id)
    values (v_session_id, v_user, v_professor_id)
    on conflict (session_id, user_id) do nothing
    returning checked_in_at into v_checked_in_at;
  v_already_registered := not found;
  if v_already_registered then
    select checked_in_at into v_checked_in_at from public.hunt_checkins
      where session_id = v_session_id and user_id = v_user;
  end if;
  return jsonb_build_object(
    'session_id', v_session_id, 'professor_id', v_professor_id,
    'checked_in_at', v_checked_in_at,
    'already_registered', v_already_registered);
end;
$$;
create or replace function public.check_in_campus_hunt_qr(p_qr_code text)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.check_in_campus_hunt_qr(p_qr_code); $$;
revoke all on function private.check_in_campus_hunt_qr(text),
  public.check_in_campus_hunt_qr(text) from public, anon, authenticated;
grant execute on function private.check_in_campus_hunt_qr(text),
  public.check_in_campus_hunt_qr(text) to authenticated;

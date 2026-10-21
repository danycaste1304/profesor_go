-- Profesor GO — SQL helpers and RPCs (docs/CONTRACTS.md §2, §9)

-- ---------------------------------------------------------------------------
-- is_admin(): used by RLS policies. security definer so it can read profiles
-- without recursing into the profiles policies.
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

grant execute on function public.is_admin() to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- collection_counts(p_user): internal helper (not callable by app roles).
-- total    = active professors
-- captured = captures of the user on active professors
-- completed = total > 0 and captured >= total
-- ---------------------------------------------------------------------------
create or replace function public.collection_counts(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with t as (
    select count(*)::int as total from public.professors where active
  ),
  c as (
    select count(*)::int as captured
    from public.captures cap
    join public.professors p on p.id = cap.professor_id
    where cap.user_id = p_user
      and p.active
  )
  select jsonb_build_object(
    'captured', c.captured,
    'total', t.total,
    'completed', (t.total > 0 and c.captured >= t.total)
  )
  from t, c;
$$;

revoke execute on function public.collection_counts(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- collection_progress(p_user default auth.uid()) -> {captured, total, completed}
-- Players may only query their own progress; admins may query anyone.
-- ---------------------------------------------------------------------------
create or replace function public.collection_progress(p_user uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- No JWT subject (anon / service context): refuse rather than leak counts.
  -- service_role can use collection_counts(uuid) directly.
  if auth.uid() is null or p_user is null then
    raise exception 'collection_progress: authentication required'
      using errcode = '42501';
  end if;
  if p_user <> auth.uid() and not public.is_admin() then
    raise exception 'collection_progress: players may only query their own collection'
      using errcode = '42501';
  end if;
  return public.collection_counts(p_user);
end;
$$;

revoke execute on function public.collection_progress(uuid) from public, anon;
grant execute on function public.collection_progress(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- admin_stats() -> {total_players, total_captures, active_professors, completed_collections}
-- ---------------------------------------------------------------------------
create or replace function public.admin_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_stats: admin only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'total_players', (select count(*) from public.profiles where role = 'player'),
    'total_captures', (select count(*) from public.captures),
    'active_professors', (select count(*) from public.professors where active),
    'completed_collections', (select count(*) from public.profiles where collection_completed_at is not null)
  );
end;
$$;

revoke execute on function public.admin_stats() from public, anon;
grant execute on function public.admin_stats() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- resolve_capture_tx: atomic capture resolution used by the resolve-capture
-- Edge Function (service_role only). Signature fixed by CONTRACTS §9.
-- ---------------------------------------------------------------------------
create or replace function public.resolve_capture_tx(
  p_encounter_id uuid,
  p_user_id      uuid,
  p_throw_quality text,
  p_roll         numeric default null   -- valor en [0,1); null => random() en SQL
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_enc        public.encounters%rowtype;
  v_prof       public.professors%rowtype;
  v_capture    public.captures%rowtype;
  v_bonus      numeric;
  v_p          numeric;
  v_roll       numeric;
  v_collection jsonb;
begin
  if p_throw_quality is null
     or p_throw_quality not in ('MISS', 'GOOD', 'GREAT', 'EXCELLENT') then
    raise exception 'resolve_capture_tx: invalid throw_quality %', p_throw_quality
      using errcode = '22023';
  end if;
  if p_roll is not null and (p_roll < 0 or p_roll >= 1) then
    raise exception 'resolve_capture_tx: p_roll must be in [0,1), got %', p_roll
      using errcode = '22023';
  end if;

  -- Lock the encounter row for the rest of the transaction.
  select * into v_enc
  from public.encounters
  where id = p_encounter_id
  for update;

  if not found then
    return pg_catalog.jsonb_build_object(
      'outcome', 'NOT_FOUND',
      'professor_id', null,
      'probability', null,
      'throw_quality', p_throw_quality,
      'collection', null);
  end if;

  if v_enc.user_id is distinct from p_user_id then
    return pg_catalog.jsonb_build_object(
      'outcome', 'FORBIDDEN',
      'professor_id', null,
      'probability', null,
      'throw_quality', p_throw_quality,
      'collection', null);
  end if;

  -- Idempotent replay: already resolved successfully and the capture exists.
  if v_enc.status = 'SUCCESS' then
    select * into v_capture
    from public.captures
    where user_id = v_enc.user_id
      and professor_id = v_enc.professor_id;
    if found then
      return pg_catalog.jsonb_build_object(
        'outcome', 'ALREADY_RESOLVED',
        'professor_id', v_enc.professor_id,
        'probability', null,
        'throw_quality', v_capture.throw_quality,
        'collection', public.collection_counts(v_enc.user_id));
    end if;
  end if;

  if v_enc.status <> 'ACTIVE' then
    return pg_catalog.jsonb_build_object(
      'outcome', 'NOT_ACTIVE',
      'professor_id', v_enc.professor_id,
      'probability', null,
      'throw_quality', p_throw_quality,
      'collection', null);
  end if;

  if v_enc.expires_at < pg_catalog.now() then
    update public.encounters set status = 'EXPIRED' where id = v_enc.id;
    return pg_catalog.jsonb_build_object(
      'outcome', 'EXPIRED',
      'professor_id', v_enc.professor_id,
      'probability', null,
      'throw_quality', p_throw_quality,
      'collection', null);
  end if;

  -- Captured through another encounter meanwhile.
  if exists (
    select 1 from public.captures
    where user_id = v_enc.user_id and professor_id = v_enc.professor_id
  ) then
    update public.encounters set status = 'EXPIRED' where id = v_enc.id;
    return pg_catalog.jsonb_build_object(
      'outcome', 'ALREADY_CAPTURED',
      'professor_id', v_enc.professor_id,
      'probability', null,
      'throw_quality', p_throw_quality,
      'collection', null);
  end if;

  select * into v_prof from public.professors where id = v_enc.professor_id;

  -- p = clamp(base_capture_rate + throw_bonus[quality], 0, 1)
  select (value ->> p_throw_quality)::numeric into v_bonus
  from public.app_settings
  where key = 'throw_bonus';
  if v_bonus is null then
    -- Defaults from CONTRACTS §2 in case app_settings is missing the row.
    v_bonus := case p_throw_quality
      when 'MISS' then -1.0
      when 'GOOD' then 0.0
      when 'GREAT' then 0.10
      when 'EXCELLENT' then 0.20
    end;
  end if;
  v_p := least(1, greatest(0, v_prof.base_capture_rate + v_bonus));
  v_roll := coalesce(p_roll, pg_catalog.random());

  if v_roll < v_p then
    begin
      insert into public.captures (user_id, professor_id, encounter_id, throw_quality)
      values (v_enc.user_id, v_enc.professor_id, v_enc.id, p_throw_quality);
    exception when unique_violation then
      update public.encounters set status = 'EXPIRED' where id = v_enc.id;
      return pg_catalog.jsonb_build_object(
        'outcome', 'ALREADY_CAPTURED',
        'professor_id', v_enc.professor_id,
        'probability', v_p,
        'throw_quality', p_throw_quality,
        'collection', null);
    end;

    update public.encounters set status = 'SUCCESS' where id = v_enc.id;

    v_collection := public.collection_counts(v_enc.user_id);
    if (v_collection ->> 'completed')::boolean then
      update public.profiles
      set collection_completed_at = coalesce(collection_completed_at, pg_catalog.now())
      where id = v_enc.user_id;
    end if;

    return pg_catalog.jsonb_build_object(
      'outcome', 'SUCCESS',
      'professor_id', v_enc.professor_id,
      'probability', v_p,
      'throw_quality', p_throw_quality,
      'collection', v_collection);
  end if;

  update public.encounters set status = 'FAILED' where id = v_enc.id;
  return pg_catalog.jsonb_build_object(
    'outcome', 'FAILED',
    'professor_id', v_enc.professor_id,
    'probability', v_p,
    'throw_quality', p_throw_quality,
    'collection', null);
end;
$$;

-- Only the Edge Function (service_role) may resolve captures.
revoke execute on function public.resolve_capture_tx(uuid, uuid, text, numeric) from public, anon, authenticated;
grant execute on function public.resolve_capture_tx(uuid, uuid, text, numeric) to service_role;

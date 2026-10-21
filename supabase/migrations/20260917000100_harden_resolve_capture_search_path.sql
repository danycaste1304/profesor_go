-- Profesor GO — security hardening: resolve_capture_tx pins search_path = ''
--
-- The other security-definer functions (is_admin, collection_counts,
-- collection_progress, admin_stats, handle_new_user, protect_profile_columns)
-- already run with `set search_path = ''`; resolve_capture_tx still pinned
-- `public`, which lets anything that can create objects in `public` shadow an
-- unqualified name the body resolves at run time. Every reference in the body
-- below is schema-qualified (public.* for tables/functions, pg_catalog.* for
-- built-ins), so the empty search_path is safe.
--
-- This file is a verbatim copy of the `create or replace function` block in
-- 20260916000400_functions.sql (that migration was edited too, so a fresh
-- `supabase db reset` produces the hardened version directly); it exists so
-- databases that already applied 20260916000400 converge without a reset.
-- CREATE OR REPLACE keeps the existing privileges; the revoke/grant below is
-- repeated only to make this migration self-contained and idempotent.

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

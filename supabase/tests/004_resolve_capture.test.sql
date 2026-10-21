-- pgTAP: resolve_capture_tx outcomes (docs/CONTRACTS.md §9). Runs as postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(50);

-- fixtures ----------------------------------------------------------------------
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('50000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rc-a@test.local', '{"display_name": "RC A"}', now(), now()),
  ('50000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rc-b@test.local', '{"display_name": "RC B"}', now(), now());

insert into public.professors (id, name, display_name, rarity, base_capture_rate, active) values
  ('50000000-0000-4000-8000-0000000000c0', 'Common Test',    'Prof. Common',    'COMMON',    0.80, true),
  ('50000000-0000-4000-8000-0000000000d0', 'Legendary Test', 'Prof. Legendary', 'LEGENDARY', 0.25, true),
  ('50000000-0000-4000-8000-0000000000f0', 'Sure Test',      'Prof. Sure',      'COMMON',    1.00, true),
  ('50000000-0000-4000-8000-0000000000aa', 'Inactive Test',  'Prof. Inactive',  'COMMON',    0.80, false);

insert into public.encounters (id, user_id, professor_id, expires_at, status) values
  ('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000c0', now() + interval '3 minutes', 'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e2', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000d0', now() + interval '3 minutes', 'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e3', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000d0', now() + interval '3 minutes', 'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e4', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000d0', now() - interval '1 minute',  'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e5', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000c0', now() + interval '3 minutes', 'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e6', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000d0', now() + interval '3 minutes', 'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e7', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000f0', now() + interval '3 minutes', 'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e8', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000f0', now() + interval '3 minutes', 'ACTIVE'),
  ('50000000-0000-4000-8000-0000000000e9', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000c0', now() + interval '3 minutes', 'ACTIVE');

select set_config('test.total_active', (select count(*)::text from public.professors where active), true);

-- input validation --------------------------------------------------------------------
select throws_ok(
  $$select public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', 'AWESOME', 0)$$,
  '22023', null, 'invalid throw_quality raises 22023');
select throws_ok(
  $$select public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', 'GOOD', 1)$$,
  '22023', null, 'p_roll >= 1 raises 22023');

-- NOT_FOUND ----------------------------------------------------------------------------
select is(
  public.resolve_capture_tx('50000000-0000-4000-8000-00000000dead', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.0),
  '{"outcome": "NOT_FOUND", "professor_id": null, "probability": null, "throw_quality": "GOOD", "collection": null}'::jsonb,
  'unknown encounter -> NOT_FOUND');

-- FORBIDDEN ----------------------------------------------------------------------------
select is(
  public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000002', 'GOOD', 0.0),
  '{"outcome": "FORBIDDEN", "professor_id": null, "probability": null, "throw_quality": "GOOD", "collection": null}'::jsonb,
  'another user''s encounter -> FORBIDDEN (no professor leaked)');
select is((select status from public.encounters where id = '50000000-0000-4000-8000-0000000000e1'), 'ACTIVE', 'FORBIDDEN leaves the encounter ACTIVE');

-- SUCCESS with p_roll 0.0 ---------------------------------------------------------------
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.0)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'SUCCESS', 'COMMON + GOOD + roll 0.0 -> SUCCESS');
select is((current_setting('test.r')::jsonb ->> 'probability')::numeric, 0.80, 'probability = 0.80 + 0.0');
select is(current_setting('test.r')::jsonb ->> 'professor_id', '50000000-0000-4000-8000-0000000000c0', 'professor_id returned');
select is(current_setting('test.r')::jsonb ->> 'throw_quality', 'GOOD', 'throw_quality echoed');
select is(
  current_setting('test.r')::jsonb -> 'collection',
  jsonb_build_object('captured', 1, 'total', current_setting('test.total_active')::int, 'completed', false),
  'collection after first capture');
select is((select status from public.encounters where id = '50000000-0000-4000-8000-0000000000e1'), 'SUCCESS', 'encounter marked SUCCESS');
select is(
  (select throw_quality from public.captures where user_id = '50000000-0000-4000-8000-000000000001' and professor_id = '50000000-0000-4000-8000-0000000000c0'),
  'GOOD', 'capture row inserted with throw_quality');
select is(
  (select encounter_id from public.captures where user_id = '50000000-0000-4000-8000-000000000001' and professor_id = '50000000-0000-4000-8000-0000000000c0'),
  '50000000-0000-4000-8000-0000000000e1'::uuid, 'capture row links the encounter');

-- ALREADY_RESOLVED (idempotent replay) ---------------------------------------------------
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', 'MISS', 0.5)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'ALREADY_RESOLVED', 'replaying a SUCCESS encounter -> ALREADY_RESOLVED');
select is(current_setting('test.r')::jsonb ->> 'throw_quality', 'GOOD', 'replay returns the original capture throw_quality');
select is(current_setting('test.r')::jsonb -> 'collection' ->> 'captured', '1', 'replay returns the collection');
select is((select count(*) from public.captures where user_id = '50000000-0000-4000-8000-000000000001'), 1::bigint, 'replay does not duplicate the capture');

-- FAILED with p_roll 0.99 --------------------------------------------------------------
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e2', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.99)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'FAILED', 'LEGENDARY + GOOD + roll 0.99 -> FAILED');
select is((current_setting('test.r')::jsonb ->> 'probability')::numeric, 0.25, 'probability = 0.25');
select is(current_setting('test.r')::jsonb -> 'collection', 'null'::jsonb, 'FAILED has no collection');
select is((select status from public.encounters where id = '50000000-0000-4000-8000-0000000000e2'), 'FAILED', 'encounter marked FAILED');
select is((select count(*) from public.captures where user_id = '50000000-0000-4000-8000-000000000001' and professor_id = '50000000-0000-4000-8000-0000000000d0'), 0::bigint, 'no capture on FAILED');

-- NOT_ACTIVE (replaying a FAILED encounter) ---------------------------------------------
select is(
  public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e2', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.0) ->> 'outcome',
  'NOT_ACTIVE', 'FAILED encounter -> NOT_ACTIVE');

-- MISS always fails ----------------------------------------------------------------------
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e3', '50000000-0000-4000-8000-000000000001', 'MISS', 0.0)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'FAILED', 'MISS with roll 0.0 -> FAILED');
select is((current_setting('test.r')::jsonb ->> 'probability')::numeric, 0::numeric, 'MISS probability clamped to 0');

-- EXPIRED ----------------------------------------------------------------------------------
select is(
  public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e4', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.0) ->> 'outcome',
  'EXPIRED', 'expires_at in the past -> EXPIRED');
select is((select status from public.encounters where id = '50000000-0000-4000-8000-0000000000e4'), 'EXPIRED', 'expired encounter marked EXPIRED');
select is(
  public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e4', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.0) ->> 'outcome',
  'NOT_ACTIVE', 'EXPIRED encounter replayed -> NOT_ACTIVE');

-- ALREADY_CAPTURED (professor already captured via another encounter) --------------------
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e5', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.0)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'ALREADY_CAPTURED', 'second ACTIVE encounter for a captured professor -> ALREADY_CAPTURED');
select is(current_setting('test.r')::jsonb ->> 'professor_id', '50000000-0000-4000-8000-0000000000c0', 'ALREADY_CAPTURED returns professor_id');
select is((select status from public.encounters where id = '50000000-0000-4000-8000-0000000000e5'), 'EXPIRED', 'ALREADY_CAPTURED marks encounter EXPIRED');
select is((select count(*) from public.captures where user_id = '50000000-0000-4000-8000-000000000001'), 1::bigint, 'still a single capture');

-- unique_violation path: simulate a race by disabling the pre-check via a direct insert -----
-- (the row lock + pre-check make this unreachable in one session; we exercise the handler
--  by inserting the capture after the function's own check would have passed: not possible
--  sequentially, so we only assert the constraint itself protects duplicates)
select throws_ok(
  $$insert into public.captures (user_id, professor_id, throw_quality) values ('50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-0000000000c0', 'GOOD')$$,
  '23505', null, 'captures(user_id, professor_id) unique constraint blocks duplicates');

-- throw bonus math ---------------------------------------------------------------------------
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e6', '50000000-0000-4000-8000-000000000001', 'EXCELLENT', 0.44)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'SUCCESS', 'LEGENDARY + EXCELLENT (0.45) + roll 0.44 -> SUCCESS');
select is((current_setting('test.r')::jsonb ->> 'probability')::numeric, 0.45, 'probability = 0.25 + 0.20');
select is(current_setting('test.r')::jsonb -> 'collection' ->> 'captured', '2', 'second capture counted');

-- null roll (random()) with p = 1 -> always SUCCESS; MISS -> always FAILED --------------------
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e7', '50000000-0000-4000-8000-000000000001', 'MISS', null)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'FAILED', 'random roll + MISS -> FAILED');
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e8', '50000000-0000-4000-8000-000000000001', 'GREAT', null)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'SUCCESS', 'random roll + p = 1.0 -> SUCCESS');
select is((current_setting('test.r')::jsonb ->> 'probability')::numeric, 1::numeric, 'probability clamped to 1');

-- collection completion ----------------------------------------------------------------------
-- user B captures every active professor through encounters; the last one completes the set.
insert into public.encounters (user_id, professor_id, expires_at)
select '50000000-0000-4000-8000-000000000002', id, now() + interval '3 minutes'
from public.professors where active;

select is(
  (select count(*) filter (where r ->> 'outcome' = 'SUCCESS')
   from (select public.resolve_capture_tx(e.id, e.user_id, 'GOOD', 0.0) as r
         from public.encounters e where e.user_id = '50000000-0000-4000-8000-000000000002') s),
  current_setting('test.total_active')::bigint,
  'every active professor captured by user B');
select is(
  public.collection_counts('50000000-0000-4000-8000-000000000002'),
  jsonb_build_object('captured', current_setting('test.total_active')::int, 'total', current_setting('test.total_active')::int, 'completed', true),
  'collection completed for user B');
select isnt(
  (select collection_completed_at from public.profiles where id = '50000000-0000-4000-8000-000000000002'),
  null, 'profiles.collection_completed_at set on completion');
select is(
  (select collection_completed_at from public.profiles where id = '50000000-0000-4000-8000-000000000001'),
  null, 'user A (incomplete) has no collection_completed_at');
select is(
  (select count(*) from public.captures where user_id = '50000000-0000-4000-8000-000000000002' and professor_id = '50000000-0000-4000-8000-0000000000aa'),
  0::bigint, 'inactive professor never captured (no encounter)');

-- inactive professors excluded from total in the RPC's collection ---------------------------------
update public.professors set active = false where id = '50000000-0000-4000-8000-0000000000d0';
select set_config('test.r', public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e9', '50000000-0000-4000-8000-000000000001', 'GOOD', 0.0)::text, true);
select is(current_setting('test.r')::jsonb ->> 'outcome', 'ALREADY_CAPTURED', 'e9 (already captured professor) -> ALREADY_CAPTURED');
select is(
  (public.collection_counts('50000000-0000-4000-8000-000000000001') ->> 'total')::int,
  current_setting('test.total_active')::int - 1,
  'deactivated professor excluded from total');
select is(
  (public.collection_counts('50000000-0000-4000-8000-000000000001') ->> 'captured')::int, 2,
  'user A captured = 2 active (common + sure)');

-- role restrictions --------------------------------------------------------------------------------
set local role authenticated;
select throws_ok(
  $$select public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', 'GOOD', 0)$$,
  '42501', null, 'authenticated cannot execute resolve_capture_tx');
reset role;
set local role anon;
select throws_ok(
  $$select public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', 'GOOD', 0)$$,
  '42501', null, 'anon cannot execute resolve_capture_tx');
reset role;
set local role service_role;
select lives_ok(
  $$select public.resolve_capture_tx('50000000-0000-4000-8000-0000000000e1', '50000000-0000-4000-8000-000000000001', 'GOOD', 0)$$,
  'service_role can execute resolve_capture_tx');
reset role;

select * from finish();
rollback;

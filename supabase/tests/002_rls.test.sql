-- pgTAP: RLS matrix (docs/CONTRACTS.md §3) simulated with request.jwt.claims + set role.
-- Player writes are executed as the player and verified afterwards as postgres
-- (bypassrls). Tables with revoked write privileges reject them with 42501;
-- tables that still grant writes but have no matching RLS policy filter them.
begin;
create extension if not exists pgtap with schema extensions;
select plan(41);

-- fixtures (as postgres, bypassrls): fresh users so the test is independent of seed state
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('30000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-player@test.local', '{"display_name": "RLS Player"}', now(), now()),
  ('30000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-admin@test.local',  '{"display_name": "RLS Admin"}',  now(), now()),
  ('30000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'rls-other@test.local',  '{"display_name": "RLS Other"}',  now(), now());
update public.profiles set role = 'admin' where id = '30000000-0000-4000-8000-000000000002';

insert into public.professors (id, name, display_name, description, rarity, base_capture_rate, active) values
  ('30000000-0000-4000-8000-0000000000aa', 'Inactive Prof', 'Prof. Inactive', 'hidden', 'COMMON', 0.8, false),
  ('30000000-0000-4000-8000-0000000000bb', 'Active Prof',   'Prof. Active',   'visible', 'COMMON', 0.8, true);

insert into public.encounters (id, user_id, professor_id, expires_at) values
  ('30000000-0000-4000-8000-0000000000e1', '30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-0000000000bb', now() + interval '3 minutes'),
  ('30000000-0000-4000-8000-0000000000e2', '30000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-0000000000bb', now() + interval '3 minutes');

insert into public.captures (id, user_id, professor_id, encounter_id, throw_quality) values
  ('30000000-0000-4000-8000-0000000000c1', '30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-0000000000bb', null, 'GOOD'),
  ('30000000-0000-4000-8000-0000000000c2', '30000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-0000000000bb', null, 'GOOD');

-- ============================================================================
-- as PLAYER
-- ============================================================================
select set_config('request.jwt.claims', '{"sub": "30000000-0000-4000-8000-000000000001", "role": "authenticated"}', true);
set local role authenticated;

select is(auth.uid(), '30000000-0000-4000-8000-000000000001'::uuid, 'auth.uid() resolves from request.jwt.claims');

-- profiles
select results_eq(
  $$select email from public.profiles$$,
  $$values ('rls-player@test.local')$$,
  'player sees only own profile');
select lives_ok(
  $$update public.profiles set display_name = 'Renamed' where id = '30000000-0000-4000-8000-000000000001'$$,
  'player can update own display_name');
select is((select display_name from public.profiles where id = '30000000-0000-4000-8000-000000000001'), 'Renamed', 'display_name updated');
select throws_ok(
  $$update public.profiles set role = 'admin' where id = '30000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'player cannot change own role');
select throws_ok(
  $$update public.profiles set collection_completed_at = now() where id = '30000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'player cannot set own collection_completed_at');
select lives_ok(
  $$update public.profiles set display_name = 'Hacked' where id = '30000000-0000-4000-8000-000000000003'$$,
  'player update on another profile is filtered (no error, no rows)');

-- professors
select is((select count(*) from public.professors where active = false), 0::bigint, 'player does not see inactive professors');
select ok(exists (select 1 from public.professors where id = '30000000-0000-4000-8000-0000000000bb'), 'player sees active professors');
select throws_ok(
  $$insert into public.professors (name, display_name, rarity, base_capture_rate) values ('x', 'x', 'COMMON', 0.5)$$,
  '42501', null, 'player cannot insert professors');
select lives_ok(
  $$update public.professors set description = 'hacked' where id = '30000000-0000-4000-8000-0000000000bb'$$,
  'player update on professors is filtered');
select lives_ok(
  $$delete from public.professors where id = '30000000-0000-4000-8000-0000000000bb'$$,
  'player delete on professors is filtered');

-- nfc_tags: no access at all
select is_empty($$select * from public.nfc_tags$$, 'player cannot read nfc_tags');
select throws_ok(
  $$insert into public.nfc_tags (tag_identifier) values ('HACK-TAG')$$,
  '42501', null, 'player cannot insert nfc_tags');
select lives_ok($$delete from public.nfc_tags$$, 'player delete on nfc_tags is filtered');

-- encounters
select results_eq(
  $$select id from public.encounters$$,
  $$values ('30000000-0000-4000-8000-0000000000e1'::uuid)$$,
  'player sees only own encounters');
select throws_ok(
  $$insert into public.encounters (user_id, professor_id, expires_at) values ('30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-0000000000bb', now())$$,
  '42501', null, 'player cannot insert encounters');
select throws_ok(
  $$update public.encounters set status = 'SUCCESS' where id = '30000000-0000-4000-8000-0000000000e1'$$,
  '42501', null, 'player cannot update own encounter');

-- captures
select results_eq(
  $$select id from public.captures$$,
  $$values ('30000000-0000-4000-8000-0000000000c1'::uuid)$$,
  'player sees only own captures');
select throws_ok(
  $$insert into public.captures (user_id, professor_id, throw_quality) values ('30000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000003', 'GOOD')$$,
  '42501', null, 'player cannot insert captures');
select throws_ok(
  $$update public.captures set throw_quality = 'EXCELLENT' where id = '30000000-0000-4000-8000-0000000000c1'$$,
  '42501', null, 'player cannot update own capture');
select throws_ok(
  $$delete from public.captures where id = '30000000-0000-4000-8000-0000000000c1'$$,
  '42501', null, 'player cannot delete own capture');

-- app_settings
select ok(exists (select 1 from public.app_settings where key = 'throw_bonus'), 'player can read app_settings');
select throws_ok(
  $$insert into public.app_settings (key, value) values ('hack', '1'::jsonb)$$,
  '42501', null, 'player cannot insert app_settings');
select lives_ok(
  $$update public.app_settings set value = '1'::jsonb where key = 'throw_bonus'$$,
  'player update on app_settings is filtered');

-- privileged functions
select throws_ok(
  $$select public.resolve_capture_tx('30000000-0000-4000-8000-0000000000e1', '30000000-0000-4000-8000-000000000001', 'GOOD', 0)$$,
  '42501', null, 'player cannot execute resolve_capture_tx');
select throws_ok(
  $$select public.collection_counts('30000000-0000-4000-8000-000000000001')$$,
  '42501', null, 'player cannot execute collection_counts');

reset role;
select set_config('request.jwt.claims', '', true);

-- ============================================================================
-- verify as postgres that the filtered writes changed nothing
-- ============================================================================
select is((select display_name from public.profiles where id = '30000000-0000-4000-8000-000000000003'), 'RLS Other', 'other profile untouched');
select is((select description from public.professors where id = '30000000-0000-4000-8000-0000000000bb'), 'visible', 'professor untouched');
select is((select status from public.encounters where id = '30000000-0000-4000-8000-0000000000e1'), 'ACTIVE', 'encounter untouched');
select is((select throw_quality from public.captures where id = '30000000-0000-4000-8000-0000000000c1'), 'GOOD', 'capture untouched');
select is((select count(*) from public.nfc_tags where tag_identifier like 'DEMO-TAG-__'), 10::bigint, 'nfc_tags untouched');
select is((select value ->> 'MISS' from public.app_settings where key = 'throw_bonus'), '-1.0', 'app_settings untouched');

-- ============================================================================
-- as ADMIN
-- ============================================================================
select set_config('request.jwt.claims', '{"sub": "30000000-0000-4000-8000-000000000002", "role": "authenticated"}', true);
set local role authenticated;

select ok(exists (select 1 from public.profiles where id = '30000000-0000-4000-8000-000000000003'), 'admin sees other profiles');
select ok(exists (select 1 from public.professors where id = '30000000-0000-4000-8000-0000000000aa'), 'admin sees inactive professors');
select ok((select count(*) from public.nfc_tags where tag_identifier like 'DEMO-TAG-__') = 10, 'admin reads nfc_tags');
select lives_ok(
  $$insert into public.nfc_tags (tag_identifier, professor_id) values ('RLS-TEST-TAG', '30000000-0000-4000-8000-0000000000bb')$$,
  'admin can insert nfc_tags');
select lives_ok(
  $$update public.professors set description = 'edited by admin' where id = '30000000-0000-4000-8000-0000000000bb'$$,
  'admin can update professors');
select is((select description from public.professors where id = '30000000-0000-4000-8000-0000000000bb'), 'edited by admin', 'professor update persisted');
select ok(exists (select 1 from public.encounters where id = '30000000-0000-4000-8000-0000000000e2'), 'admin sees other users encounters');
select ok(exists (select 1 from public.captures where id = '30000000-0000-4000-8000-0000000000c2'), 'admin sees other users captures');

reset role;

select * from finish();
rollback;

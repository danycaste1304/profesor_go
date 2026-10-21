-- pgTAP: schema, RLS flags, indexes, functions, triggers, privileges, seed, storage.
-- Runs as postgres (bypassrls). Everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(88);

-- tables ---------------------------------------------------------------------
select has_table('public', 'profiles',     'profiles table exists');
select has_table('public', 'professors',   'professors table exists');
select has_table('public', 'nfc_tags',     'nfc_tags table exists');
select has_table('public', 'encounters',   'encounters table exists');
select has_table('public', 'captures',     'captures table exists');
select has_table('public', 'app_settings', 'app_settings table exists');

-- key columns / constraints ----------------------------------------------------
select has_column('public', 'profiles',   'collection_completed_at', 'profiles.collection_completed_at exists');
select has_column('public', 'professors', 'base_capture_rate',       'professors.base_capture_rate exists');
select has_column('public', 'captures',   'throw_quality',           'captures.throw_quality exists');
select col_is_unique('public', 'nfc_tags', 'tag_identifier', 'nfc_tags.tag_identifier is unique');
select col_is_unique('public', 'captures', array['user_id', 'professor_id'], 'captures(user_id, professor_id) is unique');
select throws_ok(
  $$insert into public.professors (name, display_name, rarity, base_capture_rate) values ('x', 'x', 'MYTHIC', 0.5)$$,
  '23514', null, 'rarity check constraint rejects unknown values');
select throws_ok(
  $$insert into public.professors (name, display_name, rarity, base_capture_rate) values ('x', 'x', 'COMMON', 1.5)$$,
  '23514', null, 'base_capture_rate must be within [0,1]');

-- RLS enabled on every table ----------------------------------------------------
select is((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),     true, 'RLS enabled on profiles');
select is((select relrowsecurity from pg_class where oid = 'public.professors'::regclass),   true, 'RLS enabled on professors');
select is((select relrowsecurity from pg_class where oid = 'public.nfc_tags'::regclass),     true, 'RLS enabled on nfc_tags');
select is((select relrowsecurity from pg_class where oid = 'public.encounters'::regclass),   true, 'RLS enabled on encounters');
select is((select relrowsecurity from pg_class where oid = 'public.captures'::regclass),     true, 'RLS enabled on captures');
select is((select relrowsecurity from pg_class where oid = 'public.app_settings'::regclass), true, 'RLS enabled on app_settings');

-- indexes -----------------------------------------------------------------------
select has_index('public', 'encounters', 'encounters_user_id_status_idx', array['user_id', 'status'], 'index encounters(user_id, status)');
select has_index('public', 'captures',   'captures_user_id_idx',          array['user_id'],           'index captures(user_id)');
select has_index('public', 'nfc_tags',   'nfc_tags_tag_identifier_key',   array['tag_identifier'],    'index nfc_tags(tag_identifier)');

-- functions ---------------------------------------------------------------------
select has_function('public', 'is_admin',            '{}'::name[],                              'is_admin() exists');
select has_function('public', 'collection_progress', array['uuid'],                             'collection_progress(uuid) exists');
select has_function('public', 'admin_stats',         '{}'::name[],                              'admin_stats() exists');
select has_function('public', 'resolve_capture_tx',  array['uuid', 'uuid', 'text', 'numeric'],  'resolve_capture_tx(uuid,uuid,text,numeric) exists');
select has_function('public', 'handle_new_user',     '{}'::name[],                              'handle_new_user() exists');
select is_definer('public', 'is_admin',           '{}'::name[],                             'is_admin() is security definer');
select is_definer('public', 'resolve_capture_tx', array['uuid', 'uuid', 'text', 'numeric'], 'resolve_capture_tx is security definer');

-- privileges: only service_role may execute resolve_capture_tx ---------------------
select function_privs_are('public', 'resolve_capture_tx', array['uuid', 'uuid', 'text', 'numeric'], 'anon',          '{}'::text[],     'anon cannot execute resolve_capture_tx');
select function_privs_are('public', 'resolve_capture_tx', array['uuid', 'uuid', 'text', 'numeric'], 'authenticated', '{}'::text[],     'authenticated cannot execute resolve_capture_tx');
select function_privs_are('public', 'resolve_capture_tx', array['uuid', 'uuid', 'text', 'numeric'], 'service_role',  array['EXECUTE'], 'service_role can execute resolve_capture_tx');
select function_privs_are('public', 'collection_progress', array['uuid'], 'authenticated', array['EXECUTE'], 'authenticated can execute collection_progress');
select function_privs_are('public', 'admin_stats',         '{}'::name[],  'authenticated', array['EXECUTE'], 'authenticated can execute admin_stats');

-- triggers ----------------------------------------------------------------------
select has_trigger('public', 'professors', 'professors_set_updated_at', 'professors updated_at trigger exists');
select has_trigger('public', 'profiles',   'profiles_protect_columns',  'profiles role-protection trigger exists');
select has_trigger('auth',   'users',      'on_auth_user_created',      'auth.users -> profiles trigger exists');

select lives_ok(
  $$update public.professors set updated_at = '2000-01-01' where id = '00000000-0000-4000-8000-000000000016'$$,
  'update professor');
select isnt(
  (select updated_at from public.professors where id = '00000000-0000-4000-8000-000000000016'),
  '2000-01-01'::timestamptz,
  'updated_at trigger overwrites the value with now()');

select lives_ok(
  $$insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values ('20000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
            'trigger-test@profesorgo.local', '{"display_name": "Trigger Test"}'::jsonb, now(), now())$$,
  'insert into auth.users');
select is(
  (select display_name from public.profiles where id = '20000000-0000-4000-8000-000000000001'),
  'Trigger Test', 'profile created by trigger with display_name from metadata');
select is(
  (select role from public.profiles where id = '20000000-0000-4000-8000-000000000001'),
  'player', 'trigger assigns role player');

-- storage -----------------------------------------------------------------------
select is((select count(*) from storage.buckets where id in ('professor-sprites', 'game-assets') and public), 2::bigint,
  'public buckets professor-sprites and game-assets exist');
select is((select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'game buckets:%'), 4::bigint,
  'storage.objects has the 4 game-bucket policies');

-- seed --------------------------------------------------------------------------
select is((select count(*) from public.professors where active), 10::bigint, '10 active seed professors');
select is((select count(*) from public.nfc_tags where tag_identifier like 'DEMO-TAG-__'), 10::bigint, '10 demo tags');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-01'), '00000000-0000-4000-8000-000000000016'::uuid, 'DEMO-TAG-01 -> Henry');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000016' and active), 'COMMON', 'Henry is common');
select ok(position('MAC' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000016')) > 0, 'Henry teaches MAC');
select ok(not exists (select 1 from public.professors where id = '00000000-0000-4000-8000-000000000001' and active), 'old Ada sample is inactive or absent');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-02'), '00000000-0000-4000-8000-000000000015'::uuid, 'DEMO-TAG-02 -> Felipe');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000015' and active), 'EPIC', 'Felipe is the active epic professor');
select is((select base_capture_rate from public.professors where id = '00000000-0000-4000-8000-000000000015'), 0.40::numeric, 'Felipe has the epic capture rate');
select ok(position('Machine Learning' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000015')) > 0, 'Felipe has his supplied specialty');
select ok(position('maestrías de Ciencia de Datos e IA' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000015')) > 0, 'Felipe has his graduate program role');
select ok(not exists (select 1 from public.professors where id = '00000000-0000-4000-8000-000000000002' and active), 'old Turing sample is inactive or absent');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-03'), '00000000-0000-4000-8000-000000000014'::uuid, 'DEMO-TAG-03 -> Jose David');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000014' and active), 'COMMON', 'Jose David is the active common professor');
select is((select base_capture_rate from public.professors where id = '00000000-0000-4000-8000-000000000014'), 0.80::numeric, 'Jose David has the common capture rate');
select ok(position('materias son llevaderas' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000014')) > 0, 'Jose David has his supplied class profile');
select ok(not exists (select 1 from public.professors where id = '00000000-0000-4000-8000-000000000003' and active), 'old Hopper sample is inactive or absent');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-04'), '00000000-0000-4000-8000-000000000013'::uuid, 'DEMO-TAG-04 -> Ricardo');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000013' and active), 'RARE', 'Ricardo is the active rare professor');
select ok(position('Redes' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000013')) > 0, 'Ricardo has his supplied subject');
select ok(position('advisor de CS' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000013')) > 0, 'Ricardo is the CS advisor');
select ok(not exists (select 1 from public.professors where id = '00000000-0000-4000-8000-000000000004' and active), 'old Dijkstra sample is inactive or absent');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-05'), '00000000-0000-4000-8000-000000000012'::uuid, 'DEMO-TAG-05 -> Pavel');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000012' and active), 'EPIC', 'Pavel is an active epic professor');
select ok(position('Inteligencia Artificial' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000012')) > 0, 'Pavel has his supplied subject');
select ok(not exists (select 1 from public.professors where id = '00000000-0000-4000-8000-000000000005' and active), 'old rare sample is inactive or absent');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-06'), '00000000-0000-4000-8000-000000000011'::uuid, 'DEMO-TAG-06 -> Noel');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-07'), '00000000-0000-4000-8000-000000000009'::uuid, 'DEMO-TAG-07 -> Daniel');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-08'), '00000000-0000-4000-8000-000000000010'::uuid, 'DEMO-TAG-08 -> Erick');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-09'), '00000000-0000-4000-8000-000000000017'::uuid, 'DEMO-TAG-09 -> Diego');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000017' and active), 'RARE', 'Diego is rare');
select is((select professor_id from public.nfc_tags where tag_identifier = 'DEMO-TAG-10'), '00000000-0000-4000-8000-000000000018'::uuid, 'DEMO-TAG-10 -> Roberto');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000018' and active), 'COMMON', 'Roberto is common');
select ok(position('CMP' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000018')) > 0, 'Roberto teaches CMP');
select is((select count(*) from public.professors where active and rarity = 'LEGENDARY' and id in ('00000000-0000-4000-8000-000000000009', '00000000-0000-4000-8000-000000000010')), 2::bigint, 'Daniel and Erick are the two active legends');
select ok(position('Netflix' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000010')) > 0, 'Erick has his supplied profile');
select is((select rarity from public.professors where id = '00000000-0000-4000-8000-000000000011' and active), 'EPIC', 'Noel is the active epic professor');
select ok(position('Estructuras de Datos' in (select description from public.professors where id = '00000000-0000-4000-8000-000000000011')) > 0, 'Noel has his supplied subjects');
select ok(not exists (select 1 from public.professors where id = '00000000-0000-4000-8000-000000000006' and active), 'old epic sample is inactive or absent');
select ok(not exists (select 1 from public.professors where active and id in ('00000000-0000-4000-8000-000000000007', '00000000-0000-4000-8000-000000000008')), 'old placeholder legends are inactive');
select is((select role from public.profiles where email = 'admin@profesorgo.local'), 'admin', 'seed admin has role admin');
select is((select role from public.profiles where email = 'player@profesorgo.local'), 'player', 'seed player has role player');
select is((select value from public.app_settings where key = 'encounter_expiration_seconds'), '180'::jsonb, 'encounter_expiration_seconds = 180');
select is((select (value ->> 'MISS')::numeric from public.app_settings where key = 'throw_bonus'), -1.0, 'throw_bonus.MISS = -1.0');

select * from finish();
rollback;

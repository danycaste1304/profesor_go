-- QR rotation, RLS, atomic encounter replacement and hunt attendance.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, aud, role, email, created_at, updated_at) values
  ('80000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'qr-admin@test.local', now(), now()),
  ('80000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'qr-publisher@test.local', now(), now()),
  ('80000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'qr-student@test.local', now(), now());
update public.profiles set role = 'admin'
  where id = '80000000-0000-4000-8000-000000000001';
insert into public.professors (id, name, display_name, rarity, base_capture_rate)
  values ('80000000-0000-4000-8000-000000000099', 'QR Test', 'Prof. QR', 'COMMON', 0.8);
insert into public.hunt_publishers (professor_id, user_id)
  values ('80000000-0000-4000-8000-000000000099', '80000000-0000-4000-8000-000000000002');
create temp table qr_test_secret (code text);
grant select, insert on qr_test_secret to authenticated;

select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
insert into qr_test_secret
  select public.admin_rotate_professor_qr('80000000-0000-4000-8000-000000000099');
select is((select length(code) from qr_test_secret), 43, 'QR secret has 256 bits in base64url');
select is((select count(*) from public.professor_qr_codes), 1::bigint, 'admin sees QR metadata');
reset role;
select is((select code_hash from public.professor_qr_codes
  where professor_id = '80000000-0000-4000-8000-000000000099'),
  (select encode(extensions.digest(code, 'sha256'), 'hex') from qr_test_secret),
  'database stores only the QR hash');

select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.professor_qr_codes), 0::bigint, 'student cannot list QR hashes');
select throws_ok(
  $$select public.admin_rotate_professor_qr('80000000-0000-4000-8000-000000000099')$$,
  '42501', 'ADMIN_REQUIRED', 'student cannot rotate a QR');
select is(has_function_privilege('authenticated',
  'public.start_encounter_tx(uuid,text,text,integer)', 'EXECUTE'), false,
  'client cannot invoke privileged encounter RPC');
reset role;

select is((public.start_encounter_tx(
  '80000000-0000-4000-8000-000000000003', null,
  (select code from qr_test_secret), 180)->>'outcome'), 'SUCCESS',
  'first QR starts an encounter');
select is((public.start_encounter_tx(
  '80000000-0000-4000-8000-000000000003', null,
  (select code from qr_test_secret), 180)->>'outcome'), 'SUCCESS',
  'second QR replaces the active encounter');
select is((select count(*) from public.encounters where
  user_id = '80000000-0000-4000-8000-000000000003' and
  professor_id = '80000000-0000-4000-8000-000000000099' and status = 'ACTIVE'),
  1::bigint, 'only one active encounter remains');
insert into public.captures (user_id, professor_id, throw_quality)
  values ('80000000-0000-4000-8000-000000000003',
          '80000000-0000-4000-8000-000000000099', 'GOOD');
select is((public.start_encounter_tx(
  '80000000-0000-4000-8000-000000000003', null,
  (select code from qr_test_secret), 180)->>'outcome'), 'ALREADY_CAPTURED',
  'captured professor does not start again');

select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is(public.check_in_campus_hunt_qr((select code from qr_test_secret)), null::jsonb,
  'QR does not record attendance before a hunt');
reset role;
select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select lives_ok(
  $$select public.start_campus_hunt('80000000-0000-4000-8000-000000000099')$$,
  'publisher starts a hunt');
reset role;
select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is((public.check_in_campus_hunt_qr((select code from qr_test_secret))->>'already_registered')::boolean,
  false, 'QR check-in counts despite prior capture');
select is((public.check_in_campus_hunt_qr((select code from qr_test_secret))->>'already_registered')::boolean,
  true, 'repeat QR check-in is idempotent');
reset role;
select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is(public.admin_set_professor_qr_active('80000000-0000-4000-8000-000000000099', false),
  true, 'admin can disable a printed QR');
reset role;
select is((public.start_encounter_tx(
  '80000000-0000-4000-8000-000000000003', null,
  (select code from qr_test_secret), 180)->>'outcome'), 'TAG_DISABLED',
  'disabled QR cannot start encounters');

select * from finish();
rollback;

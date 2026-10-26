-- The hunt must be time-limited, writable only by its publisher, and allow
-- one NFC check-in per student even when the professor is already captured.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, aud, role, email, created_at, updated_at) values
  ('70000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'publisher@test.local', now(), now()),
  ('70000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'student@test.local', now(), now()),
  ('70000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'outsider@test.local', now(), now());
insert into public.professors (id, name, display_name, rarity, base_capture_rate)
values ('70000000-0000-4000-8000-000000000099', 'Hunt Test', 'Prof. Hunt', 'COMMON', 0.8);
insert into public.nfc_tags (id, professor_id, tag_identifier)
values ('70000000-0000-4000-8000-000000000098', '70000000-0000-4000-8000-000000000099', 'HUNT-TEST-TAG');
insert into public.hunt_publishers (professor_id, user_id)
values ('70000000-0000-4000-8000-000000000099', '70000000-0000-4000-8000-000000000001');
insert into public.captures (user_id, professor_id, throw_quality)
values ('70000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000099', 'GOOD');

select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$select public.start_campus_hunt('70000000-0000-4000-8000-000000000099')$$,
  '42501', 'NOT_HUNT_PUBLISHER', 'a student cannot start a hunt');
select throws_ok(
  $$insert into public.hunt_sessions (professor_id, publisher_id, ends_at) values
    ('70000000-0000-4000-8000-000000000099', '70000000-0000-4000-8000-000000000002', now() + interval '30 minutes')$$,
  '42501', null, 'a student cannot insert a hunt session directly');
select is(public.check_in_campus_hunt('HUNT-TEST-TAG'), null::jsonb,
  'a valid tag does not register attendance before a hunt starts');

reset role;
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select lives_ok(
  $$select public.start_campus_hunt('70000000-0000-4000-8000-000000000099')$$,
  'the assigned publisher can start');
select is(
  (select ends_at - started_at from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099'),
  interval '30 minutes', 'the server fixes the duration at 30 minutes');
select lives_ok(
  $$select public.update_campus_hunt_location(
    (select id from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099'),
    -0.1969, -78.4362, 15)$$,
  'the publisher can share a fresh position');
select throws_ok(
  $$select public.update_campus_hunt_location(
    (select id from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099'),
    -0.1969, -78.4362, 101)$$,
  '22023', 'INVALID_LOCATION', 'poor accuracy is rejected');

reset role;
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099'),
  1::bigint, 'a student can see a fresh active hunt');
select throws_ok(
  $$select public.update_campus_hunt_location(
    (select id from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099'),
    -0.1969, -78.4362, 15)$$,
  '42501', 'HUNT_NOT_ACTIVE', 'a student cannot publish a location');
select is((public.check_in_campus_hunt('HUNT-TEST-TAG')->>'already_registered')::boolean,
  false, 'a previously captured professor still counts as found');
select is((public.check_in_campus_hunt('HUNT-TEST-TAG')->>'already_registered')::boolean,
  true, 'a repeated scan is idempotent');
select is(public.stop_campus_hunt(
  (select id from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099')),
  false, 'a student cannot stop a hunt');

reset role;
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is(public.stop_campus_hunt(
  (select id from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099')),
  true, 'the publisher can stop the hunt');

reset role;
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.hunt_sessions where professor_id = '70000000-0000-4000-8000-000000000099'),
  0::bigint, 'a student cannot read a stopped session');
select is(public.check_in_campus_hunt('HUNT-TEST-TAG'), null::jsonb,
  'the tag no longer registers attendance after the stop');

reset role;
select * from finish();
rollback;

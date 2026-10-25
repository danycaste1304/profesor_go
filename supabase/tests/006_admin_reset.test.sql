-- pgTAP: only the event owner can restart their own collection.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, aud, role, email, created_at, updated_at) values
  ('37b8f998-df0e-454e-bc4d-76714e0ad9dc', 'authenticated', 'authenticated', 'owner@test.local', now(), now()),
  ('60000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'other-admin@test.local', now(), now()),
  ('60000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'player@test.local', now(), now());
update public.profiles set role = 'admin' where id in (
  '37b8f998-df0e-454e-bc4d-76714e0ad9dc',
  '60000000-0000-4000-8000-000000000001'
);
update public.profiles set collection_completed_at = now()
  where id = '37b8f998-df0e-454e-bc4d-76714e0ad9dc';

insert into public.professors (id, name, display_name, rarity, base_capture_rate)
values ('60000000-0000-4000-8000-000000000099', 'Test', 'Prof. Test', 'COMMON', 0.8);
insert into public.encounters (id, user_id, professor_id, expires_at) values
  ('60000000-0000-4000-8000-000000000011', '37b8f998-df0e-454e-bc4d-76714e0ad9dc', '60000000-0000-4000-8000-000000000099', now() + interval '3 minutes'),
  ('60000000-0000-4000-8000-000000000012', '60000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000099', now() + interval '3 minutes');
insert into public.captures (user_id, professor_id, throw_quality) values
  ('37b8f998-df0e-454e-bc4d-76714e0ad9dc', '60000000-0000-4000-8000-000000000099', 'GOOD'),
  ('60000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000099', 'GOOD');

select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select public.reset_my_profedex()$$, '42501', null,
  'player cannot reset the owner collection');

reset role;
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select public.reset_my_profedex()$$, '42501', null,
  'another admin cannot reset the owner collection');

reset role;
select set_config('request.jwt.claims', '{"sub":"37b8f998-df0e-454e-bc4d-76714e0ad9dc","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$select public.reset_my_profedex()$$,
  'owner can reset own collection');
select lives_ok($$select public.reset_my_profedex()$$,
  'reset is safe to repeat');

reset role;
select is((select count(*) from public.captures where user_id = '37b8f998-df0e-454e-bc4d-76714e0ad9dc'), 0::bigint,
  'owner captures are gone');
select is((select count(*) from public.encounters where user_id = '37b8f998-df0e-454e-bc4d-76714e0ad9dc'), 0::bigint,
  'owner encounters are gone');
select is((select collection_completed_at from public.profiles where id = '37b8f998-df0e-454e-bc4d-76714e0ad9dc'), null::timestamptz,
  'owner completion timestamp is cleared');
select is((select count(*) from public.captures where user_id = '60000000-0000-4000-8000-000000000002'), 1::bigint,
  'other player capture is preserved');
select is((select count(*) from public.encounters where user_id = '60000000-0000-4000-8000-000000000002'), 1::bigint,
  'other player encounter is preserved');

select * from finish();
rollback;

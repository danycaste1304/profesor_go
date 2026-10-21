-- pgTAP: is_admin(), collection_progress(), admin_stats()
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- fixtures
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('40000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'fn-player@test.local', '{"display_name": "Fn Player"}', now(), now()),
  ('40000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'fn-admin@test.local',  '{"display_name": "Fn Admin"}',  now(), now()),
  ('40000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'fn-full@test.local',   '{"display_name": "Fn Full"}',   now(), now());
update public.profiles set role = 'admin' where id = '40000000-0000-4000-8000-000000000002';

insert into public.professors (id, name, display_name, rarity, base_capture_rate, active) values
  ('40000000-0000-4000-8000-0000000000aa', 'Inactive Prof', 'Prof. Inactive', 'COMMON', 0.8, false);

-- player: 2 captures on active professors + 1 on the inactive one (must not count)
insert into public.captures (user_id, professor_id, throw_quality) values
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000016', 'GOOD'),
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000015', 'GREAT'),
  ('40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-0000000000aa', 'GOOD');

-- "full" user: captured every active professor
insert into public.captures (user_id, professor_id, throw_quality)
select '40000000-0000-4000-8000-000000000003', id, 'GOOD' from public.professors where active;

select set_config('test.total_active', (select count(*)::text from public.professors where active), true);

-- no JWT at all --------------------------------------------------------------------
select is(public.is_admin(), false, 'is_admin() is false without a JWT');
select throws_ok($$select public.collection_progress()$$, '42501', null, 'collection_progress() without JWT raises');
select throws_ok($$select public.collection_progress('40000000-0000-4000-8000-000000000001')$$, '42501', null, 'collection_progress(uuid) without JWT raises');

-- as player -----------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "40000000-0000-4000-8000-000000000001", "role": "authenticated"}', true);
set local role authenticated;

select is(public.is_admin(), false, 'is_admin() false for player');
select is(
  public.collection_progress(),
  jsonb_build_object('captured', 2, 'total', current_setting('test.total_active')::int, 'completed', false),
  'collection_progress(): 2 captured, inactive professor excluded, not completed');
select is(
  public.collection_progress('40000000-0000-4000-8000-000000000001'),
  public.collection_progress(),
  'collection_progress(own uuid) equals collection_progress()');
select throws_ok(
  $$select public.collection_progress('40000000-0000-4000-8000-000000000003')$$,
  '42501', null, 'player cannot query another user''s collection');
select throws_ok($$select public.admin_stats()$$, '42501', null, 'player cannot call admin_stats()');

reset role;

-- as "full" user --------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "40000000-0000-4000-8000-000000000003", "role": "authenticated"}', true);
set local role authenticated;

select is(
  public.collection_progress(),
  jsonb_build_object('captured', current_setting('test.total_active')::int, 'total', current_setting('test.total_active')::int, 'completed', true),
  'collection_progress(): completed when every active professor is captured');

reset role;

-- as admin -----------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "40000000-0000-4000-8000-000000000002", "role": "authenticated"}', true);
set local role authenticated;

select is(public.is_admin(), true, 'is_admin() true for admin');
select is(
  (public.collection_progress('40000000-0000-4000-8000-000000000001') ->> 'captured')::int, 2,
  'admin can query another user''s collection');
select ok(public.admin_stats() ?& array['total_players', 'total_captures', 'active_professors', 'completed_collections'],
  'admin_stats() has the 4 keys');
select is((public.admin_stats() ->> 'active_professors')::int, current_setting('test.total_active')::int, 'admin_stats.active_professors counts active only');
select ok((public.admin_stats() ->> 'total_players')::int >= 2, 'admin_stats.total_players counts players');
select ok((public.admin_stats() ->> 'total_captures')::int >= 3 + current_setting('test.total_active')::int, 'admin_stats.total_captures counts all captures');

reset role;

-- inactive professors excluded from total --------------------------------------------
update public.professors set active = false where id = '00000000-0000-4000-8000-000000000016';
select is(
  (public.collection_counts('40000000-0000-4000-8000-000000000001') ->> 'total')::int,
  current_setting('test.total_active')::int - 1,
  'deactivating a professor removes it from total');
select is(
  (public.collection_counts('40000000-0000-4000-8000-000000000001') ->> 'captured')::int, 1,
  'deactivating a captured professor removes it from captured');
select is(
  (public.collection_counts('40000000-0000-4000-8000-000000000003') ->> 'completed')::boolean, true,
  'full user still completed after a professor is deactivated');

select * from finish();
rollback;

-- pgTAP: security properties that must not regress silently.
--
-- 001/002/003/004 pin the schema, the RLS matrix seen from a player session and
-- the RPC behaviour. This file pins the *catalog shape* behind them, so a later
-- migration cannot quietly widen the attack surface while every behavioural
-- test still passes:
--   * every security definer function pins search_path (search_path hijacking);
--   * resolve_capture_tx is executable by service_role and nobody else;
--   * nfc_tags is admin-only and players have no policy at all;
--   * captures/encounters expose no write policy to authenticated;
--   * the public storage buckets only accept small, non-executable media.
-- Runs as postgres (bypassrls). Everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

-- security definer functions pin search_path -----------------------------------
-- A security definer function that inherits the caller's search_path lets anyone
-- who can create objects in a schema on that path shadow an unqualified name.
select is_empty(
  $$select p.proname::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and coalesce(array_to_string(p.proconfig, ','), '') not like '%search_path=%'$$,
  'every security definer function in public pins search_path');
select cmp_ok(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef),
  '>=', 6::bigint,
  'the security definer functions are still there (the check above is not vacuous)');
select is(
  (select p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'resolve_capture_tx'),
  array['search_path=""'],
  'resolve_capture_tx pins the empty search_path (every name in its body is qualified)');

-- resolve_capture_tx is reachable only with service_role -------------------------
-- Stricter than 001's function_privs_are: this enumerates *every* grantee, so a
-- new grant to anon, authenticated, PUBLIC or any other role fails the test.
select is(
  (select coalesce(string_agg(g, ', ' order by g), '(none)')
   from (
     select pg_get_userbyid(a.grantee)::text || '=' || a.privilege_type as g
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     cross join lateral aclexplode(p.proacl) a
     where n.nspname = 'public' and p.proname = 'resolve_capture_tx'
       and a.grantee <> p.proowner
   ) s),
  'service_role=EXECUTE',
  'resolve_capture_tx: service_role is the only role granted EXECUTE (not anon/authenticated)');
select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(p.proacl) a
    where n.nspname = 'public' and p.proname = 'resolve_capture_tx' and a.grantee = 0),
  'resolve_capture_tx is not executable by PUBLIC');

-- nfc_tags: admin only, players have no policy ----------------------------------
select is((select relrowsecurity from pg_class where oid = 'public.nfc_tags'::regclass), true,
  'RLS is enabled on nfc_tags');
select policies_are('public', 'nfc_tags', array['nfc_tags: admins full access'],
  'nfc_tags has exactly one policy');
select is_empty(
  $$select policyname::text from pg_policies
    where schemaname = 'public' and tablename = 'nfc_tags'
      and coalesce(qual, with_check, '') not like '%is_admin%'$$,
  'every nfc_tags policy is gated on public.is_admin() (no policy grants players access)');
select is_empty(
  $$select policyname::text from pg_policies
    where schemaname = 'public' and tablename = 'nfc_tags'
      and roles <> array['authenticated']::name[]$$,
  'no nfc_tags policy is granted to anon or PUBLIC');

-- captures / encounters: read-only for authenticated ------------------------------
-- Writes happen only through Edge Functions with service_role (which bypasses RLS).
select is_empty(
  $$select tablename::text || ' / ' || policyname::text from pg_policies
    where schemaname = 'public' and tablename in ('captures', 'encounters') and cmd <> 'SELECT'$$,
  'captures/encounters have no INSERT/UPDATE/DELETE policy');
select policies_are('public', 'captures', array['captures: players read own, admins read all'],
  'captures has exactly one (select) policy');
select policies_are('public', 'encounters', array['encounters: players read own, admins read all'],
  'encounters has exactly one (select) policy');
select is_empty(
  $$select tablename::text || ' / ' || policyname::text from pg_policies
    where schemaname = 'public' and tablename in ('captures', 'encounters')
      and roles <> array['authenticated']::name[]$$,
  'captures/encounters policies are scoped to authenticated (anon gets nothing)');

-- storage buckets: only small, non-executable media ---------------------------------
-- Both buckets are public for read, so an image/svg+xml (an XML document that can
-- carry <script>) stored here would be stored XSS on the storage origin.
select is(
  (select allowed_mime_types from storage.buckets where id = 'professor-sprites'),
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif'],
  'professor-sprites allows only raster image types');
select is(
  (select file_size_limit from storage.buckets where id = 'professor-sprites'),
  2097152::bigint,
  'professor-sprites is limited to 2 MiB per object');
select is(
  (select allowed_mime_types from storage.buckets where id = 'game-assets'),
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'audio/mpeg', 'audio/ogg'],
  'game-assets allows only raster image and audio types');
select is(
  (select file_size_limit from storage.buckets where id = 'game-assets'),
  5242880::bigint,
  'game-assets is limited to 5 MiB per object');
select is_empty(
  $$select id::text from storage.buckets
    where id in ('professor-sprites', 'game-assets')
      and allowed_mime_types && array['image/svg+xml', 'text/html', 'text/xml', 'application/xml',
                                      'application/javascript', 'text/javascript', 'application/pdf']$$,
  'no game bucket allows a scriptable mime type');
select is_empty(
  $$select b.id::text || ' / ' || t from storage.buckets b, unnest(b.allowed_mime_types) t
    where b.id in ('professor-sprites', 'game-assets')
      and t not like 'image/%' and t not like 'audio/%'$$,
  'every allowed mime type is an image or audio container');
select is_empty(
  $$select id::text from storage.buckets
    where id in ('professor-sprites', 'game-assets')
      and (allowed_mime_types is null or file_size_limit is null)$$,
  'neither game bucket is left unconstrained');
select is_empty(
  $$select policyname::text from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'game buckets:%' and cmd <> 'SELECT'
      and coalesce(with_check, qual, '') not like '%is_admin%'$$,
  'every game-bucket write policy is gated on public.is_admin()');

select * from finish();
rollback;

-- Profesor GO — storage buckets (docs/CONTRACTS.md §3)
-- professor-sprites: pixel-art sprites shown in the app.
-- game-assets: other static game media (backgrounds, icons, audio, ...).
-- Both are publicly readable; only admins can upload/replace/delete.
--
-- Because the buckets are public, storage itself constrains what may be stored
-- in them: raster-only image types (plus audio containers for game-assets) and
-- a size ceiling. Scriptable types such as image/svg+xml are rejected by the
-- storage API before the object is written, which stops a stored-XSS payload
-- from ever being served from the storage origin. Kept in sync with
-- 20260917000200_storage_mime_allowlist.sql, which converges databases that
-- already applied this migration in its unconstrained form.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('professor-sprites', 'professor-sprites', true, 2097152,  -- 2 MiB
   array['image/png', 'image/jpeg', 'image/webp', 'image/gif']),
  ('game-assets', 'game-assets', true, 5242880,              -- 5 MiB
   array['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'audio/mpeg', 'audio/ogg'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "game buckets: public read"
  on storage.objects for select
  using (bucket_id in ('professor-sprites', 'game-assets'));

create policy "game buckets: admins insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id in ('professor-sprites', 'game-assets') and (select public.is_admin()));

create policy "game buckets: admins update"
  on storage.objects for update
  to authenticated
  using (bucket_id in ('professor-sprites', 'game-assets') and (select public.is_admin()))
  with check (bucket_id in ('professor-sprites', 'game-assets') and (select public.is_admin()));

create policy "game buckets: admins delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id in ('professor-sprites', 'game-assets') and (select public.is_admin()));

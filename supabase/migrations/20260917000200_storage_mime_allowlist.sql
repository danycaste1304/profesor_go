-- Profesor GO — security hardening: constrain the storage buckets server-side.
--
-- Both buckets are PUBLIC for read (docs/CONTRACTS.md §3), so every object in
-- them is served from the storage origin to anonymous browsers. Until now
-- neither bucket declared `allowed_mime_types` nor `file_size_limit`, so an
-- admin token (or anything that ever obtains one) could store, for example, an
-- `image/svg+xml` file: SVG is an XML document, the browser executes the
-- `<script>` it carries, and it would run on the Supabase storage origin —
-- stored XSS against anyone who opens a sprite URL. The same hole allows
-- arbitrarily large uploads (the only ceiling was the global 50 MiB in
-- config.toml).
--
-- The allowlists below contain raster-only image types (a PNG/JPEG/WebP/GIF is
-- decoded as pixels, never executed) and, for game-assets, the two audio
-- container formats the client uses. SVG, HTML, JS, JSON, PDF and every other
-- active or scriptable type are rejected by storage itself, before the object
-- is written — a server-side control that does not depend on the admin UI.
--
-- game-assets also holds sound effects / music besides backgrounds and icons,
-- so `audio/mpeg` (.mp3) and `audio/ogg` (.ogg) are warranted: they are opaque
-- media containers with no scripting surface, and leaving them out would push
-- audio into some unconstrained bucket instead. Its 5 MiB limit is larger than
-- the sprites' 2 MiB because a music loop is legitimately bigger than a
-- pixel-art sprite.
--
-- Idempotent on purpose (`update … set`), so it converges databases that
-- already applied 20260916000600_storage.sql. That migration was updated to
-- create the buckets already constrained, so a fresh `supabase db reset`
-- produces exactly the state this file enforces.

update storage.buckets
set file_size_limit    = 2097152,  -- 2 MiB
    allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
where id = 'professor-sprites';

update storage.buckets
set file_size_limit    = 5242880,  -- 5 MiB
    allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'image/gif',
                               'audio/mpeg', 'audio/ogg']
where id = 'game-assets';

-- Fail loudly instead of migrating into a half-constrained state.
do $$
declare
  v_ok integer;
begin
  select count(*) into v_ok
  from storage.buckets
  where id in ('professor-sprites', 'game-assets')
    and allowed_mime_types is not null
    and file_size_limit is not null;
  if v_ok <> 2 then
    raise exception 'expected 2 constrained storage buckets, found %', v_ok;
  end if;
end;
$$;

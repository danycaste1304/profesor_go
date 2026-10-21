-- Replace the two highest-tier sample professors with real campus professors.
-- Keep fresh IDs so prior captures of the examples never unlock the new cards.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000009', 'Daniel Riofrio', 'Prof. Daniel',
   'Coordinador de MAC y CMP. «Todo es un experimento social». Uno de los profesores más poderosos e inteligentes del campus.',
   'LEGENDARY', 0.25, true),
  ('00000000-0000-4000-8000-000000000010', 'Erick Ñauñay', 'Prof. Erick',
   'Uno de los profesores legendarios del campus.',
   'LEGENDARY', 0.25, true)
on conflict (id) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  description = excluded.description,
  rarity = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active = excluded.active;

update public.professors
set active = false
where id in (
  '00000000-0000-4000-8000-000000000007',
  '00000000-0000-4000-8000-000000000008'
);

update public.nfc_tags
set professor_id = '00000000-0000-4000-8000-000000000009'
where tag_identifier = 'DEMO-TAG-07';

update public.nfc_tags
set professor_id = '00000000-0000-4000-8000-000000000010'
where tag_identifier = 'DEMO-TAG-08';

-- A previous 8/8 completion must not remain unlocked at 6/8 after the swap.
update public.profiles as player
set collection_completed_at = null
where collection_completed_at is not null
  and exists (
    select 1
    from public.professors as professor
    where professor.active
      and not exists (
        select 1
        from public.captures as capture
        where capture.user_id = player.id
          and capture.professor_id = professor.id
      )
  );

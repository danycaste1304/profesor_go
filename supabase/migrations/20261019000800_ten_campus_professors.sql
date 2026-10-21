-- Complete the first campus roster. New IDs prevent captures of historical
-- example cards from unlocking the professors who replace them.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000016', 'Henry Carvajal', 'Prof. Henry',
   'Profesor de MAC, amable y buena onda con sus estudiantes.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000017', 'Diego Morales', 'Prof. Diego',
   'Profesor de MAC. Es tan difícil encontrárselo que aquí aparece como raro. Cuando se deja ver, llega con buena onda.', 'RARE', 0.60, true),
  ('00000000-0000-4000-8000-000000000018', 'Roberto Andrade', 'Prof. Roberto',
   'Profesor de CMP. Gentil, sencillo y muy buena gente con sus estudiantes.', 'COMMON', 0.80, true)
on conflict (id) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  description = excluded.description,
  rarity = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active = excluded.active;

update public.professors
set active = false
where id = '00000000-0000-4000-8000-000000000001';

insert into public.nfc_tags (professor_id, tag_identifier, active)
values
  ('00000000-0000-4000-8000-000000000016', 'DEMO-TAG-01', true),
  ('00000000-0000-4000-8000-000000000017', 'DEMO-TAG-09', true),
  ('00000000-0000-4000-8000-000000000018', 'DEMO-TAG-10', true)
on conflict (tag_identifier) do update set
  professor_id = excluded.professor_id,
  active = excluded.active;

-- Existing players still need to find these additions to finish the album.
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

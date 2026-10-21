-- Replace the remaining epic sample with Noel while keeping eight active cards.
-- A new ID prevents a prior capture of the sample from unlocking Noel.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000011', 'Noel Perez', 'Prof. Noel',
   'Profesor cubano de Bases de Datos y Estructuras de Datos. Sus exámenes son retadores; enseña bien y anima a sus estudiantes a ser más sociables.',
   'EPIC', 0.40, true)
on conflict (id) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  description = excluded.description,
  rarity = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active = excluded.active;

update public.professors
set active = false
where id = '00000000-0000-4000-8000-000000000006';

update public.nfc_tags
set professor_id = '00000000-0000-4000-8000-000000000011'
where tag_identifier = 'DEMO-TAG-06';

-- An old 8/8 completion must be cleared until Noel is captured.
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

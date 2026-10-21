-- Replace the common sample at tag 03 while keeping eight active cards.
-- A new ID prevents a Hopper capture from counting as Jose David.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000014', 'Jose David Vega', 'Prof. Jose David',
   'Enseña muy bien y sus materias son llevaderas. Es un profe muy buena onda, cercano y querido por sus estudiantes.',
   'COMMON', 0.80, true)
on conflict (id) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  description = excluded.description,
  rarity = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active = excluded.active;

update public.professors
set active = false
where id = '00000000-0000-4000-8000-000000000003';

update public.nfc_tags
set professor_id = '00000000-0000-4000-8000-000000000014'
where tag_identifier = 'DEMO-TAG-03';

-- A previously completed collection now requires Jose David's capture.
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

-- Replace the common sample at tag 02 with an epic campus professor.
-- A new ID prevents an old Turing capture from counting as Felipe.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000015', 'Felipe Grijalva', 'Prof. Felipe',
   'Excoordinador de MAC y experto en Machine Learning. Está a cargo de las maestrías de Ciencia de Datos e IA. Su aire serio impone respeto, pero es buena gente.',
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
where id = '00000000-0000-4000-8000-000000000002';

update public.nfc_tags
set professor_id = '00000000-0000-4000-8000-000000000015'
where tag_identifier = 'DEMO-TAG-02';

-- A previously completed collection now requires Felipe's capture.
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

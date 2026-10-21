-- Replace the rare sample at tag 05 with Pavel, keeping eight active cards.
-- A new ID prevents an old capture of Liskov from discovering Pavel.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000012', 'Pavel Alba', 'Prof. Pavel',
   'Experto en Inteligencia Artificial y el «papá de la carrera». Su oficina está en nuestro laboratorio; explica increíble y hace sus clases súper interactivas.',
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
where id = '00000000-0000-4000-8000-000000000005';

update public.nfc_tags
set professor_id = '00000000-0000-4000-8000-000000000012'
where tag_identifier = 'DEMO-TAG-05';

-- A previously completed collection needs Pavel before it is complete again.
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

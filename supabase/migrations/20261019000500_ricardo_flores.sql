-- Replace the sample at tag 04 with Ricardo while keeping eight active cards.
-- A distinct ID avoids counting a Dijkstra capture as a Ricardo capture.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000013', 'Ricardo Flores', 'Prof. Ricardo',
   'Experto en Redes y nuestro advisor de CS. Sus exámenes son legendariamente difíciles, pero explica muy bien.',
   'RARE', 0.60, true)
on conflict (id) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  description = excluded.description,
  rarity = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active = excluded.active;

update public.professors
set active = false
where id = '00000000-0000-4000-8000-000000000004';

update public.nfc_tags
set professor_id = '00000000-0000-4000-8000-000000000013'
where tag_identifier = 'DEMO-TAG-04';

-- Any completed collection now needs a capture of Ricardo.
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

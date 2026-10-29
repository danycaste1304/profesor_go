-- Profesores inscritos por el formulario para la fiesta Némesis.
-- IDs nuevos (019-024). Los tags NFC y los QR se registran con el flujo de admin,
-- no en este repositorio.
insert into public.professors
  (id, name, display_name, description, rarity, base_capture_rate, active)
values
  ('00000000-0000-4000-8000-000000000019', 'Patricio Rojas', 'Pato',
   'Profe de Biotecnología.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000020', 'Edison Loza', 'El Eddy',
   'Profe de Administración de Empresas.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000021', 'Sonia Kraemer', 'Sonia',
   'Profe de Artes Liberales.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000022', 'Washington Lomas', 'Washo',
   'Profe de Física.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000023', 'Rodrigo Muñoz', 'Rod',
   'Profe de Diseño Comunicacional.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000024', 'Ximena Ferro', 'LaXime',
   'Profe de Publicidad.', 'COMMON', 0.80, true)
on conflict (id) do update set
  name = excluded.name,
  display_name = excluded.display_name,
  description = excluded.description,
  rarity = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active = excluded.active;

-- Quien ya había completado la Profedex ahora necesita capturar a los nuevos.
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

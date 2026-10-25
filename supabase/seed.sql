-- Profesor GO — local seed (docs/CONTRACTS.md §5). Idempotent.
-- Loaded by `supabase db reset`. LOCAL DEVELOPMENT ONLY: it creates demo users
-- with known passwords directly in auth.users.

-- ---------------------------------------------------------------------------
-- app_settings
-- ---------------------------------------------------------------------------
insert into public.app_settings (key, value) values
  ('encounter_expiration_seconds', '180'::jsonb),
  ('throw_bonus', '{"MISS": -1.0, "GOOD": 0.0, "GREAT": 0.10, "EXCELLENT": 0.20}'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ---------------------------------------------------------------------------
-- professors (ten campus professors)
-- ---------------------------------------------------------------------------
insert into public.professors (id, name, display_name, description, rarity, base_capture_rate, active) values
  ('00000000-0000-4000-8000-000000000016', 'Henry Carvajal',   'Prof. Henry', 'Profesor de Ingeniería en Matemáticas Aplicadas y Computación en la USFQ.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000015', 'Felipe Grijalva',  'Prof. Felipe', 'Coordinador de Ingeniería en Matemáticas Aplicadas y Computación. Dirige las maestrías en Ciencia de Datos e Inteligencia Artificial e investiga aprendizaje automático.', 'EPIC', 0.40, true),
  ('00000000-0000-4000-8000-000000000014', 'José David Vega', 'Prof. José David', 'Profesor de Ciencias de la Computación. Investiga comunicaciones, aprendizaje automático y seguridad de la información.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000013', 'Ricardo Flores',   'Prof. Ricardo', 'Profesor e investigador en redes y seguridad de red. Asesora al capítulo de Computer Science de IEEE-USFQ.', 'RARE', 0.60, true),
  ('00000000-0000-4000-8000-000000000012', 'Pavel Alba',       'Prof. Pavel', 'Profesor de Ingeniería en Ciencias de la Computación en la USFQ. Comparte su interés por la inteligencia artificial con estudiantes.', 'EPIC', 0.40, true),
  ('00000000-0000-4000-8000-000000000011', 'Noel Pérez',       'Prof. Noel', 'Profesor e investigador en minería de datos, aprendizaje automático y procesamiento de imágenes.', 'EPIC', 0.40, true),
  ('00000000-0000-4000-8000-000000000009', 'Daniel Riofrío',  'Prof. Daniel', 'Coordinador de Ingeniería en Ciencias de la Computación. Investiga aprendizaje automático, seguridad y optimización.', 'LEGENDARY', 0.25, true),
  ('00000000-0000-4000-8000-000000000010', 'Erick Ñauñay',    'Prof. Erick', 'Invita a explorar retos de programación y nuevas ideas tecnológicas en Profesor GO.', 'LEGENDARY', 0.25, true),
  ('00000000-0000-4000-8000-000000000017', 'Diego Morales',   'Prof. Diego', 'Profesor de Ingeniería en Matemáticas Aplicadas y Computación en la USFQ.', 'RARE', 0.60, true),
  ('00000000-0000-4000-8000-000000000018', 'Roberto Andrade', 'Prof. Roberto', 'Profesor de Ciencias de la Computación en la USFQ. Participa en proyectos de enseñanza de programación y robótica.', 'COMMON', 0.80, true)
on conflict (id) do update set
  name              = excluded.name,
  display_name      = excluded.display_name,
  description       = excluded.description,
  rarity            = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active            = excluded.active;

-- ---------------------------------------------------------------------------
-- nfc_tags: 01 Henry, 02 Felipe, 03 Jose David, 04 Ricardo, 05 Pavel,
-- 06 Noel, 07 Daniel, 08 Erick, 09 Diego, 10 Roberto
-- ---------------------------------------------------------------------------
insert into public.nfc_tags (professor_id, tag_identifier, active)
select
  ('00000000-0000-4000-8000-' || lpad(professor_number::text, 12, '0'))::uuid,
  'DEMO-TAG-' || lpad(tag_number::text, 2, '0'),
  true
from (values (1, 16), (2, 15), (3, 14), (4, 13), (5, 12), (6, 11), (7, 9), (8, 10), (9, 17), (10, 18))
  as roster(tag_number, professor_number)
on conflict (tag_identifier) do update set
  professor_id = excluded.professor_id,
  active       = excluded.active;

-- ---------------------------------------------------------------------------
-- demo users (local only). The on_auth_user_created trigger creates profiles.
--   admin@profesorgo.local  / admin12345   (role admin)
--   player@profesorgo.local / player12345  (role player)
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-4000-8000-000000000001',
    'authenticated', 'authenticated',
    'admin@profesorgo.local',
    extensions.crypt('admin12345', extensions.gen_salt('bf')),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{"display_name": "Admin Demo"}'::jsonb,
    now(), now(),
    '', '', '', '', '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-4000-8000-000000000002',
    'authenticated', 'authenticated',
    'player@profesorgo.local',
    extensions.crypt('player12345', extensions.gen_salt('bf')),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{"display_name": "Jugador Demo"}'::jsonb,
    now(), now(),
    '', '', '', '', '', '', '', ''
  )
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(),
  u.id,
  u.id::text,
  'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true, 'phone_verified', false),
  now(), now(), now()
from auth.users u
where u.email in ('admin@profesorgo.local', 'player@profesorgo.local')
on conflict (provider_id, provider) do nothing;

-- Profiles are created by the trigger with role 'player'; promote the admin.
update public.profiles
set role = 'admin'
where email = 'admin@profesorgo.local'
  and role <> 'admin';
